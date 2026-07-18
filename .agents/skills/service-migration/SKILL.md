---
name: service-migration
description: Migrate docker-compose services to native NixOS modules — postgres patterns, oci-containers, sops secrets, and the 8-step migration runbook
license: MIT
allowed-tools: shell, read_file, write_file, glob, grep
metadata:
  triggers: migrate, migration, docker to nix, postgres migration, service migration, oci-containers, ensureUsers, ensureDBOwnership, pg_cron, sops template, postgresql
  version: 1.0.0
  updated: 2026-07-18
---

# Service Migration — Docker Compose to NixOS Modules

Reference runbook for migrating services from the legacy docker-compose stack
(`@web-services` on `osiris`) into the nunix flake. Canonical example:
`hosts/osiris/services/splitpro.nix` (native postgres + docker container).

## Architecture

**Service-first**: each service module owns its DB users, extensions, and
postgres settings. `postgresql.nix` stays server-level only.

```
hosts/osiris/services/
├── postgresql.nix      # server-level: enableTCPIP, auth, firewall, superuser, backup
├── splitpro.nix        # service: pg_cron, ensureDatabases/Users, oci-container, sops
├── convertx.nix        # service: oci-container only (no DB)
└── ...
```

Secrets live in service-specific sops blocks in `nunix-secrets/osiris/secrets.yaml`
(e.g. `splitpro:`), not a generic `postgresql:` block.

## Postgres Patterns

### Database and user provisioning

```nix
services.postgresql = {
  ensureDatabases = [ "splitpro" ];
  ensureUsers = [
    {
      name = "splitpro";            # MUST match DB name for ensureDBOwnership
      ensureDBOwnership = true;     # declarative ALTER DATABASE OWNER TO
    }
  ];
};
```

`ensureDBOwnership = true` requires `name == dbName` (NixOS assertion). This
replaces a manual `ALTER DATABASE ... OWNER TO` in postStart.

### Passwords — sops + postStart, NOT ensureClauses

`ensureClauses.password` accepts a string that lands in the **nix store**
(world-readable on host) and **git repo** (brute-forceable credential
material). The NixOS docs explicitly warn against plaintext passwords.

Use sops secret + `postgresql-setup.postStart`:

```nix
sops.secrets.splitpro_db_password = {
  key = "splitpro/db_password";
  owner = config.users.users.postgres.name;  # postgresql-setup runs as postgres
};

systemd.services.postgresql-setup.postStart = lib.mkAfter ''
  PGPW=$(cat ${config.sops.secrets.splitpro_db_password.path})
  psql -d postgres -c "ALTER USER \"splitpro\" WITH PASSWORD '$PGPW';"
'';
```

### Superuser password — no declarative alternative

The `postgres` superuser is created by `initdb`, not `ensureUsers`. There is
no `ensureClauses` path for it. Use `postgresql-setup.postStart` in
`postgresql.nix` (server-level):

```nix
sops.secrets.postgres_default_password = {
  key = "postgresql/default/password";
  owner = config.users.users.postgres.name;
};

systemd.services.postgresql-setup.postStart = ''
  PGPW=$(cat ${config.sops.secrets.postgres_default_password.path})
  psql -d postgres -c "ALTER USER postgres WITH PASSWORD '$PGPW';"
'';
```

### postStart merging

`postgresql-setup.postStart` is `types.lines` — merges across modules.
`postgresql.nix` sets the superuser password (no `mkAfter`). Service modules
use `lib.mkAfter` to run after the superuser statement:

```nix
# splitpro.nix
systemd.services.postgresql-setup.postStart = lib.mkAfter ''
  # runs after postgresql.nix's superuser ALTER
  ...
'';
```

Resulting merged postStart:
```
PGPW=$(cat /run/secrets/postgres_default_password)
psql -d postgres -c "ALTER USER postgres WITH PASSWORD '$PGPW';"

PGPW=$(cat /run/secrets/splitpro_db_password)
psql -d postgres -c "ALTER USER \"splitpro\" WITH PASSWORD '$PGPW';"
psql -d "splitpro" -c "CREATE EXTENSION IF NOT EXISTS pg_cron;"
...
```

### postgresql.target vs postgresql.service

- `postgresql.service` is active when DB is at least in read-only mode
- `postgresql.target` is active when DB is in read-write mode AND
  `postgresql-setup.service` (which runs `ensureUsers` + `postStart`) has
  completed

Container services should depend on `postgresql.target`:

```nix
systemd.services.docker-<name> = {
  after = [ "postgresql.target" ];
  requires = [ "postgresql.target" ];
};
```

### Extensions

`services.postgresql.extensions` is a **function** (`pp: [ pp.pg_cron ]`).
It does **NOT** auto-merge across modules — two services setting `extensions`
will conflict. Future fix: custom `enabledExtensions` list option in
`postgresql.nix` that maps to the `extensions` function.

`shared_preload_libraries` is a list — coerces to comma-separated string and
**DOES** merge across modules.

## pg_cron

pg_cron requires three things:

1. **Preload at server start** (cluster-wide):
   ```nix
   services.postgresql.settings.shared_preload_libraries = [ "pg_cron" ];
   ```

2. **Set the cron database** (cluster-wide — only ONE service per cluster
   can use pg_cron):
   ```nix
   services.postgresql.settings."cron.database_name" = "splitpro";
   services.postgresql.settings."cron.timezone" = "UTC";
   ```

3. **Create extension in target DB + grant schema access** (per-DB, via
   postStart — NixOS has no `ensureExtensions`):
   ```nix
   systemd.services.postgresql-setup.postStart = lib.mkAfter ''
     psql -d "splitpro" -c "CREATE EXTENSION IF NOT EXISTS pg_cron;"
     psql -d "splitpro" -c "GRANT USAGE ON SCHEMA cron TO \"splitpro\";"
     psql -d "splitpro" -c "GRANT ALL ON ALL TABLES IN SCHEMA cron TO \"splitpro\";"
     psql -d "splitpro" -c "GRANT ALL ON ALL SEQUENCES IN SCHEMA cron TO \"splitpro\";"
   '';
   ```

The `cron` schema is created by pg_cron owned by `postgres`; the service
user needs `USAGE` + `ALL` to manage its jobs.

## Docker Container Patterns

### Backend — must set explicitly

`virtualisation.oci-containers` defaults to **podman**. Set docker explicitly:

```nix
virtualisation.oci-containers.backend = "docker";
```

### Container → host postgres

```nix
extraOptions = [
  "--network=traefik_proxy"
  "--add-host=host.docker.internal:host-gateway"
];
```

### DATABASE_URL via sops template

Build the URL from parts (password from sops, rest inline):

```nix
sops.templates."splitpro_database_url" = {
  content = "postgresql://splitpro:${config.sops.placeholder.splitpro_db_password}@host.docker.internal:5432/splitpro";
  owner = config.username;  # container reads this
};
```

Mount as `*_FILE` env var (matches legacy compose `_FILE` pattern).

### Traefik labels

Via `extraOptions` (docker-label style — traefik docker provider picks up):

```nix
extraOptions = [
  "--label=traefik.enable=true"
  "--label=traefik.http.routers.<name>-rtr.entrypoints=websecure"
  "--label=traefik.http.routers.<name>-rtr.rule=Host(`<sub>.${config.publicDomain}`)"
  "--label=traefik.http.routers.<name>-rtr.middlewares=chain-no-auth@file"  # or chain-authentik
  "--label=traefik.http.routers.<name>-rtr.service=<name>-svc"
  "--label=traefik.http.services.<name>-svc.loadbalancer.server.port=3000"
  "--label=traefik.docker.network=traefik_proxy"
];
```

### Sops secret ownership

- Secrets read by `postgresql-setup` (runs as `postgres`): `owner = config.users.users.postgres.name`
- Secrets mounted into container (runs as UID 1000): `owner = config.username`
- Default mode `0400` is correct — owner is the sole reader

### systemd service override

`systemd.services.docker-<name>` merges with the unit generated by
`oci-containers`. Only set ordering, not ExecStart:

```nix
systemd.services.docker-<name> = {
  after = [ "postgresql.target" ];
  requires = [ "postgresql.target" ];
};
```

## Network

### pg_hba authentication

Docker subnets authenticate via `scram-sha-256`. Rules are inserted before
upstream defaults (local peer, 127.0.0.1/::1 md5):

```nix
services.postgresql = {
  enableTCPIP = true;
  authentication = ''
    host  all all 172.16.0.0/12    scram-sha-256
    host  all all 192.168.90.0/24  scram-sha-256
  '';
};
```

### Firewall (nftables)

```nix
networking.firewall.extraInputRules = ''
  ip saddr 172.16.0.0/12   tcp dport 5432 accept
  ip saddr 192.168.90.0/24  tcp dport 5432 accept
'';
```

## Migration Runbook (8 steps)

Template — adapt per service. Example: splitpro.

### 1. Secrets prep (in `nunix-secrets`)

- Restructure into service block (e.g. `splitpro:` with `db_password`, etc.)
- Fetch values via SSH from osiris: `ssh osiris 'cat .../secrets/<name>_*'`
- `sops updatekeys`, commit in secrets repo
- **Bump flake.lock**: `nix flake lock --update-input my-secrets`, commit `flake.lock`

### 2. Stop docker compose service

```bash
ssh osiris 'docker compose -f docker-compose-osiris.yml stop <service>'
```

Container name conflict: nixos `oci-containers` and compose can't share a
container name. Stop compose before deploying nixos.

### 3. Deploy

```bash
nix develop . --command nh os switch . --hostname osiris --target-host krokosik@osiris -e passwordless
```

Native postgres starts, DB/user/extensions created. The new nixos container
starts but can't serve (no data yet).

### 4. Stop the new nixos container

```bash
ssh osiris 'sudo systemctl stop docker-<service>'
```

Prevents it from creating empty schema via app migrations before restore.

### 5. Dump from docker postgres

```bash
ssh osiris 'docker exec postgresql pg_dump -U postgres -d <db> --no-owner --no-privileges' > /tmp/<service>.sql
```

`--no-owner --no-privileges` strips ownership (objects will be owned by
`postgres` after restore; reassign in step 7).

### 6. Restore into native postgres

```bash
# Clean schema (app may have created empty tables on startup)
ssh osiris 'sudo -u postgres psql -d <db> -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public; GRANT ALL ON SCHEMA public TO <user>; GRANT ALL ON SCHEMA public TO postgres;"'

# Restore
scp /tmp/<service>.sql osiris:/tmp/
ssh osiris 'sudo -u postgres psql -d <db> -f /tmp/<service>.sql'
```

### 7. Reassign ownership

`REASSIGN OWNED BY postgres TO <user>` fails at cluster level (system
objects). Use per-object ALTER:

```bash
ssh osiris 'sudo -u postgres psql -d <db> -c "ALTER SCHEMA public OWNER TO <user>;"

# Tables
ssh osiris 'sudo -u postgres psql -d <db> -c "DO \$\$ DECLARE r RECORD; BEGIN FOR r IN SELECT tablename FROM pg_tables WHERE schemaname = '\''public'\'' AND tableowner = '\''postgres'\'' LOOP EXECUTE '\''ALTER TABLE public.\"'\'' || r.tablename || '\''\" OWNER TO <user>'\''; END LOOP; END \$\$;"'

# Sequences
ssh osiris 'sudo -u postgres psql -d <db> -c "DO \$\$ DECLARE r RECORD; BEGIN FOR r IN SELECT sequence_name FROM information_schema.sequences WHERE sequence_schema = '\''public'\'' LOOP EXECUTE '\''ALTER SEQUENCE public.\"'\'' || r.sequence_name || '\''\" OWNER TO <user>'\''; END LOOP; END \$\$;"'

# Views
ssh osiris 'sudo -u postgres psql -d <db> -c "DO \$\$ DECLARE r RECORD; BEGIN FOR r IN SELECT viewname FROM pg_views WHERE schemaname = '\''public'\'' AND viewowner = '\''postgres'\'' LOOP EXECUTE '\''ALTER VIEW public.\"'\'' || r.viewname || '\''\" OWNER TO <user>'\''; END LOOP; END \$\$;"'

# Functions
ssh osiris 'sudo -u postgres psql -d <db> -c "DO \$\$ DECLARE r RECORD; BEGIN FOR r IN SELECT proname FROM pg_proc WHERE pronamespace = '\''public'\''::regnamespace AND proowner = '\''postgres'\''::regrole LOOP EXECUTE '\''ALTER FUNCTION public.\"'\'' || r.proname || '\''\" OWNER TO <user>'\''; END LOOP; END \$\$;"'
```

### 8. Migrate data + restart + verify

```bash
# Rsync uploads/data
ssh osiris 'sudo rsync -aP .../appdata/<service>/uploads/ /var/lib/<service>/uploads/'
ssh osiris 'sudo chown -R <uid>:<gid> /var/lib/<service>/uploads/'

# Restart container
ssh osiris 'sudo systemctl restart docker-<service>'

# Verify
ssh osiris 'curl -sL -o /dev/null -w "HTTP %{http_code}\n" https://<sub>.krokosik.com/'
```

## Gotchas

- **Container name conflict**: nixos `oci-containers` container and compose
  container can't share a name — stop compose before deploying nixos.
- **`flake.lock` stale**: bump `my-secrets` after secrets edits
  (`nix flake lock --update-input my-secrets`), commit `flake.lock`.
- **`oci-containers` defaults to podman**: set `backend = "docker"` explicitly.
- **pg_cron scheduler blocks `DROP DATABASE`**: terminate the backend
  (`SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '...'`)
  or stop postgres first.
- **View/function ownership after restore**: `REASSIGN OWNED BY postgres`
  fails (system objects) — use per-object `ALTER ... OWNER TO`.
- **`ensureClauses.password` security**: hash in nix store + git repo —
  prefer sops + postStart.
- **pg_cron cluster constraint**: `cron.database_name` is single
  cluster-wide — one service per cluster, or run a second postgres instance.
- **`postgresql-setup.postStart` runs as `postgres`**: secrets read by
  postStart must be owned by `postgres`, not the container user.
