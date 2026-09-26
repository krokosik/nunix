localhost := `hostname`
username := env('USER')
system := env('system', "x86_64-linux")

default:
    @printf '💻 \033[1mThe current host is: \033[1;33m%s\033[1m.\033[1;33m%s\033[0m\n' '{{localhost}}'
    @printf '⚙️  \033[1mThe system architecture is: \033[1;33m%s\033[0m\n' '{{system}}'
    @echo
    @just --list

# Deploy the current host using the local flake configuration
[group("nixos deploy")]
deploy-local:
    nh os switch --elevation-strategy run0 .

# Deploy a remote host using the local flake configuration. If no IP is provided, it will default to using the hostname.
[group("nixos deploy")]    
deploy-remote host ip="":
    nh os switch --hostname {{host}} --target-host {{username}}@{{ if ip == "" { host } else { ip } }} --elevation-strategy passwordless .

# Open REPL for a particular host configuration.
[group("utils")]
repl host=localhost:
    nix repl ".#nixosConfigurations.{{host}}" --show-trace 

# Enter the project devshell with all required tooling
[group("utils")]
dev:
    nix develop . 

# Generate, publish and lock an app's OIDC credentials (no overwrites).
[group("secrets")]
oidc-secrets app host="osiris":
    #!/usr/bin/env bash
    set -euo pipefail

    app="{{app}}"
    host="{{host}}"
    if [[ ! "$app" =~ ^[a-zA-Z0-9_-]+$ || ! "$host" =~ ^[a-zA-Z0-9_-]+$ ]]; then
      printf 'App and host must contain only letters, numbers, hyphens or underscores\n' >&2
      exit 1
    fi

    secrets_repo="$(git rev-parse --show-toplevel)/../nunix-secrets"
    secrets_file="$secrets_repo/$host/secrets.yaml"
    if [[ ! -f "$secrets_file" || ! -f "$secrets_repo/.sops.yaml" ]]; then
      printf 'Missing secrets file or sops config for host %s\n' "$host" >&2
      exit 1
    fi
    if [[ -n "$(git -C "$secrets_repo" status --porcelain)" ]]; then
      printf 'Secrets repo has other changes; finish those before provisioning OIDC credentials\n' >&2
      exit 1
    fi
    if [[ "$(git -C "$secrets_repo" branch --show-current)" != 'main' ]]; then
      printf 'Switch the secrets repo to main before provisioning OIDC credentials\n' >&2
      exit 1
    fi
    git -C "$secrets_repo" fetch origin main
    if [[ "$(git -C "$secrets_repo" rev-parse HEAD)" != "$(git -C "$secrets_repo" rev-parse origin/main)" ]]; then
      printf 'Secrets repo main is not synced with origin/main; sync it before provisioning\n' >&2
      exit 1
    fi

    # Decrypt only in memory. Reject partial and complete pairs alike.
    existing="$(sops decrypt --output-type json "$secrets_file" | jq --compact-output --arg app "$app" \
      '[.[$app].oidc_client_id, .[$app].oidc_client_secret] | any(. != null)')"
    if [[ "$existing" == 'true' ]]; then
      printf 'OIDC credentials already exist for %s on %s; refusing to overwrite\n' "$app" "$host" >&2
      exit 1
    fi

    # sops expects a JSON scalar on stdin. jq provides correct escaping without
    # exposing the random values on the command line or in shell tracing.
    for kind in oidc_client_id oidc_client_secret; do
      if [[ "$kind" == oidc_client_id ]]; then bytes=16; else bytes=32; fi
      od --address-radix=n --format=x1 --width="$bytes" --read-bytes="$bytes" /dev/urandom | \
        tr --delete '[:space:]' | jq --raw-input --slurp --compact-output '.' | \
        sops set --value-stdin "$secrets_file" "[\"$app\"][\"$kind\"]" >/dev/null
    done

    if [[ "$(git -C "$secrets_repo" status --porcelain | wc --lines)" != 1 ]] || \
       [[ -z "$(git -C "$secrets_repo" status --porcelain -- "$host/secrets.yaml")" ]]; then
      printf 'Unexpected changes in secrets repo; refusing to commit\n' >&2
      exit 1
    fi
    git -C "$secrets_repo" add -- "$host/secrets.yaml"
    git -C "$secrets_repo" diff --cached --check
    git -C "$secrets_repo" commit -m "Add $app OIDC credentials for $host"
    git -C "$secrets_repo" push
    nix flake update my-secrets

# Repair the Nix store by verifying and checking the contents, and attempting to repair any issues found.
[group("nix utils")]
repair-store:
    nix-store --verify --check-contents --repair

# Fetch the hash of a URL and convert it to SRI format using SHA256.
[group("nix utils")]
fetch-hash url:
    @echo "🔍 Fetching hash for URL: {{url}}..."
    nix hash convert --to sri --hash-algo sha256 $(nix-prefetch-url {{url}})

[group("nix utils")]
delete-broken-derivations depth="1":
    @echo "🧹 Deleting broken derivations with depth {{depth}}..."
    nix-store --query --referrers-closure $(find /nix/store -maxdepth {{depth}} -type f -name '*.drv' -size 0) | xargs run0 nix-store --delete --ignore-liveness

# Bootstrap a new host using the internal flake template
[group("bootstrap")]
new-host name:
    @echo "🚀 Creating new host: {{name}}"
    # Initialize the folder using your local template
    nix flake new ./hosts/{{name}} -t .#host
    # Replace the placeholder in the template with the actual hostname
    sed -i "s/new-host/{{name}}/g" ./hosts/{{name}}/default.nix
    # Stage the files so the flake can find them immediately
    git add ./hosts/{{name}}
    @echo "✅ Done!"

[group("nixos deploy")]
deploy-new host:
    nix run github:nix-community/nixos-anywhere -- --generate-hardware-config nixos-facter ./hosts/{{host}}/facter.json --flake .#{{host}} --target-host {{host}} --extra-files /tmp/nixos-anywhere-extra
