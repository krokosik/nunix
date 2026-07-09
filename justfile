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
    nh os switch .

# Deploy a remote host using the local flake configuration. If no IP is provided, it will default to using the hostname.
[group("nixos deploy")]    
deploy-remote host ip="":
    nixos-rebuild switch --flake ".#{{host}}" --target-host {{username}}@{{ if ip == "" { host } else { ip } }} --use-remote-sudo

# Open REPL for a particular host configuration.
[group("utils")]
repl host=localhost:
    nix repl ".#nixosConfigurations.{{host}}" --show-trace 

# Enter the project devshell with all required tooling
[group("utils")]
dev:
    nix develop . 

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
    nix-store --query --referrers-closure $(find /nix/store -maxdepth {{depth}} -type f -name '*.drv' -size 0) | xargs sudo nix-store --delete --ignore-liveness

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
    nix run github:nix-community/nixos-anywhere -- --generate-hardware-config nixos-facter ./hosts/{{host}}/facter.json --flake .#{{host}} --target-host {{host}}
