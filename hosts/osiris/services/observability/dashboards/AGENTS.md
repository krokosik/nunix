# GRAFANA DASHBOARDS

Use the `dashboarding` skill from `grafana/skills` for dashboard changes.
For layout and styling, also use `frontend-design`, within Grafana's native
panel capabilities. The skill is pinned as `grafana-skills` in `flake.nix` and
linked through `externalSkills` in `home-manager/private/common/slop.nix`.

## PROVISIONING

- JSON files here are provisioned by `../grafana.nix` into the Observability
  folder. Edit the repository source; production API writes and UI edits are
  not the persistence mechanism for these dashboards.
- `../prepare-dashboards.jq` normalizes imported dashboards, resolves data
  sources and scopes queries. For imported dashboards, prefer focused changes
  there over rewriting upstream JSON. For dashboards authored here, edit the
  JSON directly. Check the prepared output as well as the source.
- Preserve dashboard UIDs, filenames and existing panel IDs when possible so
  links continue to work. Dashboard UIDs must be unique across this directory;
  panel IDs must be unique within each dashboard, including collapsed rows.
- Metrics use the Prometheus-compatible `victoriametrics` data source. Logs use
  `victorialogs`. Reuse provisioned data sources; never embed credentials.
- Scope host metrics with the inventory's `host` label and the appropriate
  `job`, such as `host/node`. Use variables when the dashboard supports several
  hosts. Validate label names against live data before adding queries.

## DESIGN

- Start with the question the dashboard should answer. Put compact summary
  readings above the main trend; give the main chart more space than supporting
  diagnostics. Avoid a grid of equally prominent panels.
- Use `power.json` as the local reference for spacing, native stat panels,
  time-series styling and collapsed diagnostics. Adapt the layout to the
  subject rather than copying its colors and panel sizes mechanically.
- Keep titles short enough to fit at ordinary desktop widths. Put measurement
  scope, troubleshooting and caveats in panel descriptions or collapsed notes,
  rather than a large introductory text panel.
- Use consistent colors for the same quantities. Reserve status colors and
  thresholds for meaningful states; do not invent warning limits.
- Set units, precision, legends and axis bounds deliberately. Separate signals
  with very different magnitudes. Never stack overlapping measurements.
- Keep missing readings visibly unavailable. Do not replace absent data with
  zero, bridge gaps, or use sample data in a production dashboard.

## MEASUREMENTS

- Use counter rates for power or throughput, and counter increases for energy
  or event totals. Choose rate intervals for the scrape interval and state
  which time range an aggregate covers.
- Check behavior with partial history and gaps. An average of observed power
  samples is different from energy divided by a full day when only minutes of
  history exist. Describe coverage limitations without implying a full period
  was measured.
- RAPL measures CPU domains, not electricity at the socket. Package energy
  already includes child domains. On osiris, MSR and MMIO interfaces report the
  same package counter; exclude the duplicate MMIO interface from queries.

## VALIDATION

- Parse changed JSON with `jq` and run it through the existing preparation
  pipeline. Check unique IDs, grid placement and collapsed-row contents.
- Validate changed queries against VictoriaMetrics or VictoriaLogs when
  reachable. Distinguish an invalid query from a valid query with no data.
- For visual changes, render the prepared dashboard in a temporary Grafana
  instance and inspect it with real data in an isolated browser. Check labels,
  legends, units, clipping and empty states; include a screenshot for review.
  Do not change production authentication to obtain a preview.
- Build on lindbladian using the repository's normal validation workflow.
  Report what was checked and any unavailable checks. A build or preview does
  not authorize deployment.
