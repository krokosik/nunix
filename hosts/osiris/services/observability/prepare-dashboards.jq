# Imported JSON remains the source of layouts. Resolve import placeholders and
# adapt queries deterministically when building the provisioned JSON directory.
def vm: {type:"prometheus", uid:"victoriametrics"};
def vl: {type:"victoriametrics-logs-datasource", uid:"victorialogs"};
def variable($name; $query):
  {name:$name, label:($name|ascii_upcase), type:"query", datasource:vm,
   query:$query, definition:$query, refresh:1, sort:1, multi:false,
   includeAll:false, current:{}, options:[]};
def all_variable($name; $query):
  variable($name;$query) + {multi:true, includeAll:true, allValue:".*",
    current:{text:"All",value:"$__all"}};
def metric_scope($scope):
  if contains("host=~\"$host\"") or endswith(", host)") then .
  else gsub("\\{"; "{" + $scope + ",") end;
def query_strings(transform):
  walk(if type == "object" then
    if (.expr? | type) == "string" then .expr |= transform else . end |
    if (.definition? | type) == "string" then .definition |= transform else . end |
    if (.query? | type) == "string" and .type? != "datasource" and .type? != "interval"
      then .query |= transform else . end
  else . end);
def legacy_panels:
  walk(if type == "object" and has("targets") then
    if .type == "graph" then
      .type = "timeseries" |
      .fieldConfig.defaults = ((.fieldConfig.defaults // {}) + {
        unit:(.yaxes[0].format // "short"),
        custom:{drawStyle:(if .bars then "bars" else "line" end),
          fillOpacity:((.fill // 0)*10), lineWidth:(.linewidth // 1),
          showPoints:"never", spanNulls:false,
          stacking:{mode:(if .stack then "normal" else "none" end),group:"A"}}}) |
      .options = {legend:{displayMode:"list",placement:"bottom",showLegend:true},
        tooltip:{mode:"multi",sort:"none"}}
    elif .type == "singlestat" then
      . as $old |
      .type = "stat" |
      .fieldConfig.defaults = ((.fieldConfig.defaults // {}) + {
        unit:(.format // "short"), decimals:(.decimals // null),
        noValue:(.nullText // "No data"),
        mappings:[(.valueMaps // [])[]|{type:"value",options:{(.value):{text:.text}}}]}) |
      .fieldConfig.defaults.thresholds = {mode:"absolute",steps:
        [{value:null,color:($old.colors[0] // "green")}] +
        ([($old.thresholds // "" | split(",")[] | try tonumber catch empty)] |
          to_entries | map({value:.value,color:($old.colors[.key+1] // "red")}))} |
      .options = {reduceOptions:{calcs:["lastNotNull"],values:false},
        graphMode:"none",colorMode:(if $old.colorBackground then "background" elif $old.colorValue then "value" else "none" end),
        textMode:(.options.textMode // "auto")}
    else . end
  else . end);
def datasources:
  walk(if type == "object" and has("datasource") then
    if (.datasource|type) == "string" then
      if .datasource != "-- Grafana --" then .datasource = vm else . end
    elif .datasource.type? == "prometheus" then .datasource = vm
    else . end
  else . end) |
  .templating.list |= map(select(.type != "datasource")) |
  del(.__inputs) | .id = null | .editable = false |
  .refresh = "30s" |
  .templating.list |= map(if .type == "query" then .current = {} | .options = [] else . end);
def hostvar($metric; $job): variable("host"; "label_values("+$metric+"{job=\""+$job+"\"}, host)");

def traefik_logs: "log_type:traefik_access host:in($Host) RouterName:~\"${RouterName:regex}\"";
# Influx display-name overrides reference labels absent from the Victoria query
# result. Let the datasource's legendFormat name every series instead.
def datasource_display_names:
  del(.fieldConfig.defaults.displayName) |
  .fieldConfig.overrides = ((.fieldConfig.overrides // []) |
    map(.properties |= map(select(.id != "displayName")) |
      select((.properties | length) > 0)));
def log_panel($field):
  datasource_display_names |
  .datasource = vl |
  .targets = [{refId:"A",datasource:vl,editorMode:"code",
    expr:(traefik_logs + " | coalesce("+$field+") default \""+
      (if $field == "asn_org" or $field == "country" or $field == "city"
        then "Unavailable (private or unmapped IP)" else "Unknown" end)+
      "\" as "+$field+" | stats by ("+$field+") count() as requests"),
    queryType:(if .type == "piechart" then "stats" else "statsRange" end),
    legendFormat:("{{"+$field+"}}"),step:"$__interval"}] |
  .fieldConfig.defaults.unit = "short" |
  if .type == "timeseries" then
    .title |= sub("Queries/sec";"Requests per interval") |
    .description = "Access-log counts per Grafana query interval; not requests/second."
  else . end;
def metric_panel($expr; $title):
  datasource_display_names |
  .datasource = vm | .title = $title |
  .targets = [{refId:"A",datasource:vm,expr:$expr,legendFormat:$title}];
def ip_log_panel:
  log_panel("client_ip") |
  .targets[0].expr = traefik_logs +
    " | stats by (client_ip, city, country, asn_org) count() as requests" |
  .targets[0].legendFormat = "{{client_ip}} {{city}} {{country}} {{asn_org}}" |
  .description = "Access-log counts per interval, grouped by client IP with available city, country and ASN organisation. Private or unmapped clients have no GeoIP details.";
def traefik:
  . as $export |
  {uid:$export.metadata.name,title:$export.spec.title,
   description:"Imported Traefik layout adapted to native Prometheus metrics and enriched VictoriaLogs. GeoIP is approximate; private clients have no geographic location.",
   schemaVersion:39,version:1,refresh:"30s",editable:false,
   time:{from:"now-1h",to:"now"},tags:["observability","traefik"],
   templating:{list:[
     variable("Host";"label_values(traefik_config_reloads_total{job=\"service/traefik\"}, host)"),
     all_variable("RouterName";"label_values(traefik_router_requests_total{host=~\"$Host\"}, router)")
   ]},
   panels:(reduce $export.spec.layout.spec.rows[] as $row
     ({offset:0,panels:[]};
      .panels += (if $row.spec.hideHeader then [] else [{
        id:(10000+.offset),title:$row.spec.title,type:"row",collapsed:false,panels:[],
        gridPos:{x:0,y:.offset,w:24,h:1}
      }] end) |
      .offset += (if $row.spec.hideHeader then 0 else 1 end) |
      .offset as $offset |
      .panels += [$row.spec.layout.spec.items[] | .spec as $grid |
        $export.spec.elements[$grid.element.name].spec as $panel |
        {id:$panel.id,title:$panel.title,type:$panel.vizConfig.group,
         gridPos:{x:$grid.x,y:($grid.y+$offset),w:$grid.width,h:$grid.height},
         options:$panel.vizConfig.spec.options,fieldConfig:$panel.vizConfig.spec.fieldConfig} |
        if .id == 286 then
          metric_panel("sum(rate(traefik_router_requests_total{host=~\"$Host\",router=~\"$RouterName\"}[$__rate_interval]))";"Requests/sec") |
          .fieldConfig.defaults.unit = "reqps"
        elif .id == 671 then
          metric_panel("sum(traefik_open_connections{host=~\"$Host\"})";"Open connections (all routers)")
        elif .id == 52 or .id == 53 then
          metric_panel("sum(rate(traefik_router_responses_bytes_total{host=~\"$Host\",router=~\"$RouterName\"}[$__rate_interval]))";"Response throughput") |
          .fieldConfig.defaults.unit = "Bps"
        elif .id == 96 then
          .datasource = vl |
          .targets = [{refId:"A",datasource:vl,editorMode:"code",queryType:"instant",
            expr:(traefik_logs+" latitude:* longitude:* | stats by (latitude, longitude, city, country) count() as requests"),maxLines:1000}] |
          .options.layers = [{type:"markers",name:"Clients",config:{showLegend:true,
            style:{color:{fixed:"blue"},opacity:0.7,size:{field:"requests",fixed:5,min:5,max:20}}},
            tooltip:true,
            location:{mode:"coords",latitude:"latitude",longitude:"longitude"}}] |
          .options.view = {id:"fit",allLayers:true,lastOnly:false,maxZoom:12,padding:30} |
          .description = "GeoIP locations are approximate. Only clients with coordinates are shown; private and unmapped addresses cannot be placed geographically. Marker size represents requests in the selected time range." |
          .transformations = [
            {id:"extractFields",options:{source:"Line",format:"json",replace:true,keepTime:false}},
            {id:"convertFieldType",options:{conversions:[
            {targetField:"latitude",destinationType:"number"},
            {targetField:"longitude",destinationType:"number"},
            {targetField:"requests",destinationType:"number"}
          ]}}]
        elif (.id == 12 or .id == 31 or .id == 672) then log_panel("browser")
        elif (.id == 137 or .id == 342) then log_panel("RequestProtocol")
        elif (.id == 198 or .id == 199) then log_panel("asn_org")
        elif .id == 200 then log_panel("city")
        elif (.id == 29 or .id == 8 or .id == 540) then log_panel("DownstreamStatus")
        elif (.id == 30 or .id == 9) then ip_log_panel
        elif .id == 408 then log_panel("RouterName")
        elif .id == 409 then log_panel("ServiceName")
        elif .id == 673 then log_panel("os")
        elif .id == 674 then log_panel("device")
        elif .id == 94 then log_panel("country")
        else error("Unmapped imported Traefik panel: " + (.id|tostring)) end] |
      .offset += ([$row.spec.layout.spec.items[].spec | .y + .height]|max)
     ) | .panels)};

if $name == "traefik.json" then traefik
else
  datasources |
  if $name == "node_exporter.json" then
    .templating.list = [hostvar("node_uname_info";"host/node")] + .templating.list |
    query_strings(metric_scope("host=~\"$host\""))
  elif $name == "postgresql.json" then
    .templating.list |= map(select(.name != "namespace" and .name != "release")) |
    .templating.list = [hostvar("pg_up";"host/postgres")] + .templating.list |
    .templating.list |= map(
      if .name == "instance" then .query = "label_values(pg_up{host=~\"$host\",job=\"host/postgres\"}, instance)" | .definition = .query | .regex = ""
      elif .name == "datname" then .query = "label_values(pg_stat_database_numbackends{host=~\"$host\",job=\"host/postgres\"}, datname)" | .definition = .query
      else . end) |
    query_strings(gsub("release=\"\\$release\", ?";"") |
      metric_scope("host=~\"$host\",job=\"host/postgres\"") |
      gsub("SUM\\(";"sum(")) |
    walk(if type == "object" and has("targets") then
      if .id == 22 then .title = "Postgres exporter CPU usage" | .targets[0].expr = "rate(process_cpu_seconds_total{host=~\"$host\",job=\"host/postgres\"}[$__rate_interval])" | .yaxes[0].format = "percentunit"
      elif .id == 24 then .title = "Postgres exporter memory" | .targets |= map(.expr |= sub("avg\\(rate\\((?<metric>process_[a-z_]+)\\{.*";"\(.metric){host=~\"$host\",job=\"host/postgres\"}"))
      elif .id == 26 then .title = "Postgres exporter file descriptors"
      elif .id == 64 then .targets |= map(select(.expr|test("buffers_alloc|buffers_clean")))
      elif .id == 70 then .targets |= map(.expr |= gsub("pg_stat_bgwriter_checkpoint_write_time_total";"pg_stat_checkpointer_write_time_total") | .expr |= gsub("pg_stat_bgwriter_checkpoint_sync_time_total";"pg_stat_checkpointer_sync_time_total"))
      elif .id == 36 then .targets[0].legendFormat = "{{short_version}}" | .options.textMode = "name"
      else . end
    else . end)
  elif $name == "smart.json" then
    .templating.list = [hostvar("smartctl_device";"host/smartctl")] + .templating.list |
    query_strings(metric_scope("host=~\"$host\",job=\"host/smartctl\"")) |
    .templating.list |= map(
      if .name == "node" then
        .query.query = "label_values(smartctl_device{host=~\"$host\",job=\"host/smartctl\"}, instance)" |
        .definition = .query.query
      elif ((.query.query? // null) | type) == "string" then
        .query.query |= sub("label_values\\((?<metric>smartctl_version|smartctl_device),";
          "label_values(\(.metric){host=~\"$host\",job=\"host/smartctl\"},") |
        .definition = .query.query
      else . end)
  elif $name == "alertmanager.json" then
    query_strings(metric_scope("job=\"host/alertmanager\"") |
      gsub("instance, cluster";"instance, host, job") |
      gsub("\\$__interval";"$__rate_interval")) |
    walk(if type == "object" and has("targets") then
      .targets |= map(select((.expr? // "" | test("kube_pod_")) | not)) |
      .targets |= map(
        if (.expr? // "" | startswith("time() - (alertmanager_build_info")) then
          .expr = "time() - (alertmanager_build_info{job=\"host/alertmanager\",instance=~\"$instance\"} * on (host) group_left node_systemd_unit_start_time_seconds{job=\"host/node\",name=\"alertmanager.service\"})"
        elif (.expr? // "" | test("^alertmanager_(nflog|silences)_gc_duration_seconds\\{")) then
          .expr |= sub("^(?<metric>[^\\{]+)(?<selector>\\{.*\\})$";"\(.metric)_sum\(.selector) / \(.metric)_count\(.selector)")
        elif (.expr? // "" | test("^rate\\(alertmanager_nflog_snapshot_duration_seconds_sum")) then
          .expr |= sub(" / rate\\(alertmanager_nflog_snapshot_duration_seconds_sum";" / rate(alertmanager_nflog_snapshot_duration_seconds_count")
        else . end) |
      .description = ((.description // "") + " Event-duration panels have no value when no matching events occur in the selected interval. Kubernetes limit overlays are omitted on native NixOS.")
    else . end)
  elif $name == "authentik.json" then
    .templating.list |= map(select(.name != "namespace")) |
    .templating.list = [hostvar("authentik_admin_workers";"service/authentik")] + .templating.list |
    query_strings(gsub("namespace=~\"\\$namespace\"";"host=~\"$host\",job=\"service/authentik\"")) |
    walk(if type == "object" and has("targets") then
      if .id == 4 then
        .title = "Registered workers" |
        .targets[0].expr = "sum(authentik_admin_workers{host=~\"$host\",job=\"service/authentik\"})"
      elif .id == 16 then
        .targets[0].expr = "sum by (outpost_name) (authentik_outpost_connection{host=~\"$host\",job=\"service/authentik\"})"
      elif .id == 8 then
        .targets[0].expr = "sum by (flow_slug) (rate(authentik_flows_plan_time_sum{host=~\"$host\",job=\"service/authentik\"}[$__rate_interval])) / sum by (flow_slug) (rate(authentik_flows_plan_time_count{host=~\"$host\",job=\"service/authentik\"}[$__rate_interval]))"
      elif .id == 2 then
        .targets[0].expr = "topk(5, sum by (binding_target_type,mode) (rate(authentik_policies_execution_time_sum{host=~\"$host\",job=\"service/authentik\"}[$__rate_interval])) / sum by (binding_target_type,mode) (rate(authentik_policies_execution_time_count{host=~\"$host\",job=\"service/authentik\"}[$__rate_interval])))"
      elif .id == 11 then
        .targets[0].expr = "topk(5, sum by (object_type,mode) (rate(authentik_policies_execution_time_sum{host=~\"$host\",job=\"service/authentik\"}[$__rate_interval])) / sum by (object_type,mode) (rate(authentik_policies_execution_time_count{host=~\"$host\",job=\"service/authentik\"}[$__rate_interval])))"
      elif .id == 15 then
        .targets[0].expr = "sum by (actor_name) (rate(authentik_tasks_duration_milliseconds_sum{host=~\"$host\",job=\"service/authentik\"}[$__rate_interval])) / sum by (actor_name) (rate(authentik_tasks_duration_milliseconds_count{host=~\"$host\",job=\"service/authentik\"}[$__rate_interval]))"
      elif .id == 26 or .id == 35 then
        .title = "Flow stage execution duration" |
        .targets = [{refId:"A",datasource:vm,
          expr:"sum by (stage_type) (rate(authentik_flows_execution_stage_time_sum{host=~\"$host\",job=\"service/authentik\"}[$__rate_interval])) / sum by (stage_type) (rate(authentik_flows_execution_stage_time_count{host=~\"$host\",job=\"service/authentik\"}[$__rate_interval]))",
          legendFormat:"{{stage_type}}"}] |
        .fieldConfig.defaults.unit = "s"
      elif .id == 20 then
        .title = "Embedded outpost requests/sec" |
        .targets[0].expr = "rate(authentik_main_request_duration_seconds_count{host=~\"$host\",job=\"service/authentik\",dest=\"embedded_outpost\"}[$__rate_interval])"
      elif .id == 31 then
        .title = "Embedded outpost request duration (p95)" |
        .targets[0].expr = "authentik_main_request_duration_seconds{host=~\"$host\",job=\"service/authentik\",dest=\"embedded_outpost\",quantile=\"0.95\"}" |
        .fieldConfig.defaults.unit = "s"
      else . end |
      .description = ((.description // "") + " Empty LDAP/RADIUS sections are expected when those outposts are not deployed; timing series require matching activity.")
    else . end)
  elif $name == "haproxy.json" then
    query_strings(gsub("instance=\"\\$host\"";"host=~\"$host\",job=\"service/haproxy\"")) |
    .templating.list |= map(if .name == "host" then .query.query = "label_values(haproxy_process_start_time_seconds{job=\"service/haproxy\"}, host)" | .definition = .query.query
      elif .name == "code" then .query.query = "label_values(haproxy_frontend_http_responses_total{host=~\"$host\",job=\"service/haproxy\"}, code)" | .definition = .query.query
      elif .name == "interval" then .current = {text:"2m",value:"2m"} | .query = "2m,5m,1h,6h,1d" else . end) |
    .description = ((.description // "") + " Public frontends run in TCP mode; HTTP status and HTTP latency metrics for those frontends are not available. The loopback metrics frontend is HTTP.")
  elif $name == "garage.json" then
    query_strings(gsub("job=\"garage\"";"job=\"service/garage\",host=\"osiris\"")) |
    .description = "Garage native metrics. Request/error/I/O counters appear after matching activity. Web API panels are empty because the S3 website endpoint is not enabled."
  elif $name == "blackbox.json" then
    .templating.list = [
      all_variable("host";"label_values(probe_success, host)"),
      all_variable("ip_family";"label_values(probe_success{host=~\"$host\"}, ip_family)")
    ] + .templating.list |
    .templating.list |= map(if .name == "job" or .name == "instance" then
      .includeAll = true | .multi = true | .allValue = ".*" |
      .current = {text:"All",value:"$__all"}
    else . end) |
    query_strings(metric_scope("host=~\"$host\",ip_family=~\"$ip_family\"")) |
    walk(if type == "object" and has("targets") then
      .targets |= map(if (.expr? | type) == "string" then
        .expr |= gsub("by \\(instance\\)";"by (instance, ip_family, vantage)") |
        .legendFormat = "{{instance}} IPv{{ip_family}} from {{vantage}} {{phase}}" |
        if .format == "table" then
          .instant = true | .range = false |
          .expr = "label_join("+.expr+", \"target\", \" | \" , \"instance\", \"ip_family\", \"vantage\")"
        else . end
      else . end) |
      if .type == "table" then
        .transformations = [
          {id:"joinByField",options:{byField:"target",mode:"outerTabular"}},
          {id:"filterFieldsByName",options:{include:{names:["target","Value #A","Value #B","Value #C","Value #D","Value #E","Value #G"]}}},
          {id:"organize",options:{renameByName:{target:"URL | IP family | vantage",
            "Value #A":"Success","Value #B":"SSL","Value #C":"SSL Cert Expiry (days)",
            "Value #D":"HTTP Status","Value #E":"Duration (seconds)","Value #G":"DNS (seconds)"}}}
        ]
      else . end
    else . end)
  else . end |
  legacy_panels
end |
if ([.. | objects | .datasource? // empty | select(type == "object") | .type | select(. != "prometheus" and . != "victoriametrics-logs-datasource" and . != "datasource" and . != "grafana")] | length) > 0
then error("Unsupported datasource in " + $name) else . end
