# Observability buildup strategy

## Direction

Build coverage in small, verifiable increments. Each increment should add a
useful signal, an actionable alert where warranted, and a Grafana view of that
signal. Keep detection in the highest-semantic-level source available: use an
application's native events when they carry more meaning than a metric or log
line, metrics for measurable state, and LogsQL for events that only exist in
the journal. Alertmanager owns grouping, inhibition, silences, and delivery;
Grafana is a provisioned query and dashboard UI.

Service modules contribute through `mkObservabilityServices.<name>` alongside
their existing service, Traefik, Authentik, and database declarations. Host
exporters and hardware belong in host-level observability configuration. Rules
for other hosts must be explicitly shared with the central `osiris` evaluation;
one `nixosConfiguration` cannot collect declarations from another implicitly.
Continue with `osiris` and `anubis` only; desktops are outside this rollout.

## Phases

### 1. Make the baseline trustworthy

- Fix the public blackbox probes' address-family choice before paging from
  `probe_success`: on `osiris` the exporter currently selects an unreachable
  public IPv6 address while an IPv4 request succeeds. Then verify each of the
  six configured applications' expected HTTP response. Keep an unavailable
  unit, a failed metrics scrape, and a failed public probe distinct.
- Verify that both hosts deliver metrics and journal entries. Observe vmagent
  and vlagent forwarding failures, dropped data, and queue growth so a quiet
  central store cannot be mistaken for a healthy system.
- Exercise `HostDown`, unit failure, probe failure, certificate expiry,
  Alertmanager inhibition, and Telegram firing/resolved delivery with
  controlled tests. Confirm that an absent series cannot silently bypass a
  rule intended to detect a missing host or exporter.
- **Dashboard:** fleet overview showing both hosts, public probes, ingestion
  and alert-pipeline health, and currently firing alerts.

### 2. Protect PostgreSQL, disks, and ZFS

- Extend the already scraped PostgreSQL exporter with alerts for `pg_up`,
  exporter scrape errors, sustained connection pressure, deadlocks, and
  abnormal WAL or database-size growth. Choose thresholds after observing
  ordinary traffic; distinguish a shared database failure from failures in
  its consuming applications.
- Extend SMART coverage before adding temperature or wear alerts. The current
  exporter discovers four disks on `osiris`, but returns per-device SMART
  status for only three: investigate the NVMe system disk and explicitly
  detect when an expected disk's metrics disappear. Then cover SMART health,
  collection errors, temperature, and suitable device-specific wear signals.
- Cover `osiris`'s `rpool` and mirrored `tank`, and `anubis`'s `rpool`:
  degraded pools, read/write/checksum errors, available capacity, and failed
  or overdue scrubs. Keep the pool and physical-disk failure domains separate.
- **Dashboards:** PostgreSQL connections, deadlocks, database sizes and WAL;
  storage view with pool state, capacity, scrub history, and individual disks.

### 3. Cover the front door and security

- Scrape CrowdSec's already-enabled loopback metrics on **both** hosts. Cover
  acquisition/parser failures and the health of the agents and bouncers;
  baseline decision and AppSec traffic before alerting on unusual rates.
- Scrape Authentik server and worker metrics independently; cover worker/task
  health and readiness. Integrate high-value Authentik-native notifications
  into central routing without replacing domain events with generic log regexes.
- Add HAProxy metrics on `anubis` where supported by its configuration. Use
  existing Traefik metrics on `osiris` for sustained upstream errors and
  latency, alongside the public probes that exercise the full route.
- **Dashboard:** Traefik routers, status and latency; HAProxy backend health;
  CrowdSec decisions and processing; Authentik server/worker health.

### 4. Cover applications and their dependencies

- Extend declarations for Immich, Garage, Jellyfin, Sonarr, Radarr, Prowlarr,
  Seerr, Actual Budget, SplitPro, and remaining native/OCI services. Prefer
  native application metrics if available; otherwise combine systemd, public
  or local probes, PostgreSQL, and journal signals. Verify an endpoint's
  format and authentication before registering it for scraping.
- Add alerts for actionable failures such as an Immich worker outage, Garage
  storage/API failure, stalled media jobs, or persistent application errors.
  Suppress derivative service alerts during a confirmed host or shared
  database outage only when labels identify that dependency reliably.
- **Dashboard:** per-service health matrix with drill-down links to the
  application's metrics, relevant database, public probe, and journal logs.

### 5. Monitor scheduled work and recoverability

- Publish success timestamps and outcomes for PostgreSQL backups, Garage
  bucket provisioning, ZFS scrubs, certificate renewal, and important
  timers/oneshots. A node_exporter textfile metric is appropriate when a
  successful oneshot does not stay active.
- Alert on failed **and overdue** backups or jobs, stale success markers, and
  insufficient destination capacity. Include an explicit missing-metric case.
- **Dashboard:** jobs and backups with last success, duration, size, failure
  history, and destination free space.

### 6. Refine notifications and dashboard ownership

- Review real alert volume before adjusting severity and `for` durations.
  Keep Telegram for actionable alerts; route longer reports to the existing
  email receiver when there is a concrete report to send. Include a short
  runbook and a relevant dashboard link in alert annotations.
- Add **versioned HTML notification templates for Alertmanager's Telegram
  receiver**. Provision the templates declaratively, set Telegram's
  `parse_mode` to `HTML`, and render host, service, severity, a concise
  summary, runbook/dashboard links, and firing or resolved status. Escape
  application-provided text and links correctly for Telegram HTML; test
  grouped and resolved messages, long annotations, and delivery before
  changing the default notification format. Keep bot credentials in sops.
- Provision dashboard JSON from this directory with stable UIDs and the
  existing VictoriaMetrics/VictoriaLogs datasource UIDs. Use the old Compose
  Traefik/CrowdSec dashboards and `~/work/nixos` host/PostgreSQL dashboards as
  references, adapting their queries and labels rather than importing Loki or
  old Prometheus assumptions unchanged. Alert definitions must remain outside
  Grafana.

## Completion criteria for each increment

1. Confirm the metric, log field, or application event exists on the intended
   host, and that its labels remain stable across restarts.
2. Add the declaration beside its owning service or host; add central rules
   explicitly when they must cover multiple hosts.
3. Add or update a provisioned dashboard panel that makes the alert
   diagnosable, with `host` and `service` filtering where applicable.
4. Evaluate/build the relevant hosts, run `nix flake check`, validate generated
   rules with the pinned `vmalert -dryRun`, and test firing **and resolution**
   through Alertmanager before treating a new alert as operational.
