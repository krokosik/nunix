# Observability

`modules/common/observability.nix` defines the typed, per-host
`mkObservabilityServices.<name>` declarations. `osiris` and `anubis` are enrolled
via `mkObservability.enable` in their host configurations; desktops are not
enrolled. Central storage, alerting, ingress, and Grafana live under
`hosts/osiris/services/observability/`.

| Component | Location | Responsibility |
| --- | --- | --- |
| vmagent, node exporter, journal-upload, vlagent | Both hosts | Scrape local targets and forward metrics/journal entries |
| PostgreSQL, SMART, blackbox exporters | Where relevant | Database, physical disk, and HTTP probe signals |
| VictoriaMetrics, VictoriaLogs | `osiris` | Metrics (45 days) and logs (30 days) |
| `vmalert-metrics`, `vmalert-logs` | `osiris` | Evaluate declarative metric and LogsQL rules |
| Alertmanager | `osiris` | Grouping, host-down inhibition, silences, Telegram and email receivers |
| Grafana | `osiris` | Provisioned query datasources and UI; no Grafana-managed alerts |

Each vmagent scrapes its **own** host's application endpoints and exporters,
attaches `host` and `environment` labels, and remote-writes to VictoriaMetrics.
Normal NixOS and Docker logs enter persistent journald; systemd-journal-upload
posts the journal to local vlagent, whose bounded on-disk queue forwards it to
VictoriaLogs. On `anubis`, both agents send over HTTPS to `osiris`'s Traefik
entry point. The two ingress routers accept only `POST /api/v1/write` and
`POST /insert/native`, respectively, from `config.vpsPrivateIp`, with separate
Basic Auth credentials. Backend storage APIs listen on loopback. Traefik's
ingest-auth setup is optional for Traefik startup: failure to render the
credential files must not take down unrelated web services.

The Grafana route is **`https://grafana.${config.privateDomain}`** (currently
`grafana.ts.krokosik.com`). Its Authentik app hostname and OIDC callback must
match that route. `grafana.${config.publicDomain}` is not configured and returns
a Traefik 404. Grafana provisions VictoriaMetrics as a Prometheus datasource,
VictoriaLogs via the packaged datasource plugin, and Alertmanager for inspecting
silences. Its SQLite database holds UI state, but alert detection and
notification routing are declared in Nix.

## Registering a service

Declare observability beside the application and its Traefik/Authentik/DB
registration, rather than editing vmagent or Grafana directly. For example:

```nix
{ config, ... }:
{
  mkObservabilityServices.example = {
    units = [ "example.service" ];
    metrics.url = "http://127.0.0.1:9001/metrics";
    probes.public.url = "${config.mkTraefikServices.example.fullHostname}/health";

    metricAlerts = [
      {
        alert = "ExampleUnhealthy";
        expr = ''example_health{service="example"} == 0'';
        for = "2m";
        labels.severity = "critical";
        annotations.summary = "Example is unhealthy on {{ $labels.host }}";
      }
    ];
  };
}
```

`units` selects systemd units for node_exporter's systemd collector. A
`metrics` endpoint generates a local scrape job; `probes` generate separate
blackbox jobs. This keeps a failed unit, failed scrape, and failed public HTTP
request distinguishable. Public probes for Immich, PsiTransfer, SplitPro,
Authentik, ConvertX, and BentoPDF currently run from `osiris` using their
`mkTraefikServices.<name>.fullHostname` values. The `http_reachable` probe
module accepts 200, 302, or 401 without following redirects for login-gated
routes; use `http_2xx` for endpoints that should return a successful response.

Metric rules from service modules are collected by the `osiris` vmalert module.
Log rules use the same alert fields plus `interval = "5m"`; their groups use
`type = "vlogs"`, and `interval` determines the default LogsQL look-back
window. Shared host rules are explicitly registered in
`hosts/osiris/services/observability/rules.nix`.
**Separately evaluated hosts cannot contribute rules to `osiris` implicitly**:
rules for remote hosts must be shared as reusable Nix definitions and imported
by the central configuration. Keep application-native event detection in the
application when it contains richer information than metrics or logs.

Services opt into `RepeatedServiceErrors` by adding systemd unit names to the
mergeable `mkObservability.repeatedErrorUnits` list in their own modules:

```nix
mkObservability.repeatedErrorUnits = lib.lists.singleton config.systemd.services.example.name;
```

The central rule deduplicates and quotes the names for LogsQL, and is omitted
when the list is empty. It warns when a unit emits more than 20 structured logs
with `level` equal to `error`, `crit`, `alert`, or `emerg` in 5 minutes, grouped
by host and unit. Traefik and Authentik's server and worker are enrolled.
This requires a structured `level` field; plain-text errors alone do not match.
Remote-host registrations must still be contributed explicitly to the central
configuration, as with other rules.

## Host and storage alerts

Services opt into `SystemdUnitInactive` with the mergeable, deduplicated
`mkObservability.inactiveAlertUnits` list:

```nix
mkObservability.inactiveAlertUnits = lib.lists.singleton config.systemd.services.example.name;
```

Each host automatically includes these units in node exporter's systemd
collector and publishes `node_expected_systemd_unit_active` expectation metrics.
The central rule joins those with inactive unit states by host, environment,
instance, and unit name, alerting after 5 minutes. This works for remote-host
registrations without adding a second unit list on the central host. An empty
list disables inactive-unit alerts for that host; `monitoredUnits` and service
`units` alone select collection, not inactive alerts.
Use `lib.mkForce [ ]` to clear registrations merged from service modules.

Enroll main long-running services, not setup/configuration jobs or timers.
Nixflix registers Sonarr, Radarr, Prowlarr, FlareSolverr, Jellyfin, Seerr,
qBittorrent, and Maintainerr when enabled. Existing applications, PostgreSQL,
CrowdSec and its firewall bouncer, and the observability stack are also enrolled.

The central metric rules cover PostgreSQL availability (2 minutes) and use of
more than 85% of non-reserved connection slots (10 minutes), SMART/NVMe health
failures (2 minutes), and disk deterioration (10 minutes). Disk deterioration
means ATA pending/uncorrectable sectors, rising reallocated sectors, or new NVMe
media errors over the last 24 hours; historical reallocation/media-error totals
alone do not alert.

Node exporter's textfile collector reads immutable expectation metrics generated
from each host's configured persistent writable filesystems and ZFS pools.
These scope the filesystem read-only (2 minutes) and less-than-5%-available-space
(5 minutes) alerts, and detect missing pools (5 minutes). A reported non-online
ZFS pool alerts after 2 minutes. Kernel OOM kills alert over a 10-minute window.

The PostgreSQL backup service publishes a last-success timestamp only after the
native dump/compression script succeeds, atomically writing a metric under
`/var/lib/postgresql-backup-metrics`. The directory persists across reboots;
node exporter reads the timestamp without access to the private database dumps.
A daily backup older than 36 hours, or a missing success metric, warns after
15 minutes while node metrics are available. On first deployment the success
metric is missing until the next successful backup; existing dumps are not
treated as a recorded success automatically.

## Secrets and checks

The ingestion passwords are `observability/metrics_ingest_password` and
`observability/logs_ingest_password` in `nunix-secrets/common/secrets.yaml`.
The `osiris` host secrets contain `alertmanager/telegram_bot_token`,
`alertmanager/telegram_chat_id`, `grafana/secret_key`,
`grafana/admin_password`, and Grafana's OIDC client credentials. SMTP is
configured as an Alertmanager receiver via the existing local `msmtpd` relay;
only alerts explicitly labelled `channel="email"` are routed there. After
changing the secrets repository, update the `my-secrets` lock input before
building or deploying, as described in [Secrets Management](README.md#secrets-management).

For a quick runtime check on `osiris`, inspect `vmalert-metrics.service`,
`vmalert-logs.service`, `vmagent.service`, `vlagent.service`, and
`systemd-journal-upload.service`. For example, after writing a unique marker
with `systemd-cat --identifier=observability-check`, query metrics and logs:

```bash
curl --get --data-urlencode 'query=up{job="host/node"}' http://127.0.0.1:8428/api/v1/query
curl --get --data-urlencode 'query=probe_success' http://127.0.0.1:8428/api/v1/query
curl --get --data-urlencode 'query="unique-marker"' http://127.0.0.1:9428/select/logsql/query
```

Check both Grafana datasources in the UI. Before a new rule deployment,
validate its generated rules with the pinned
`vmalert -dryRun -rule=<generated-rules.yml>`; `nix flake check` alone checks
Nix evaluation, not every alert expression.
