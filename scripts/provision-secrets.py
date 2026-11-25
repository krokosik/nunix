#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = []
# ///
"""Add secrets to nunix-secrets without editing files by hand.

Every command refuses to overwrite existing values and runs only on a clean
secrets checkout that matches origin/main. It ends with a commit, a push and
`nix flake update my-secrets`. Secret values reach other programs only through
stdin or pipes, never as command-line arguments or files on disk. Run the
script on a host that is part of this flake, because the gRPC commands read
the host inventory from the local host's configuration.

If a command fails before its commit, nothing was published: run
`git reset --hard && git clean -d --force` in the secrets checkout (the
latter removes new certificate files) and run it again. If it fails after
the commit, finish by hand with `git push` in the secrets repo and
`nix flake update my-secrets`.
"""

import argparse
import json
import os
import re
import secrets
import shutil
import socket
import subprocess
import sys
from contextlib import contextmanager
from pathlib import Path

NUNIX = Path(__file__).resolve().parent.parent
SECRETS = NUNIX.parent / "nunix-secrets"
# Directory in the secrets repo that holds the public nix-grpc-store files
CERTS = "nix-grpc-store"
NAME = re.compile(r"^[A-Za-z0-9_-]+$")


class Abort(Exception):
    pass


def run(*args: str, input: str | None = None, cwd: Path | None = None, fds: tuple[int, ...] = ()) -> str:
    result = subprocess.run(args, input=input, cwd=cwd or SECRETS, capture_output=True, text=True, pass_fds=fds)
    if result.returncode != 0:
        raise Abort(f"`{' '.join(args[:3])}` failed:\n{result.stderr.strip()}")
    return result.stdout


@contextmanager
def pipes(*values: str):
    """Write each value into a pipe and yield /dev/fd paths that a child process can read."""
    fds = []
    try:
        for value in values:
            data = value.encode()
            read, write = os.pipe()
            fds += [read, write]
            # Pipe capacity varies, but a pipe always holds at least PIPE_BUF
            # bytes, so a value that fits is written before any reader starts
            limit = os.fpathconf(write, "PC_PIPE_BUF")
            if len(data) > limit:
                raise Abort(f"value of {len(data)} bytes is larger than the {limit} byte pipe limit")
            os.write(write, data)
            os.close(fds.pop())
        yield [f"/dev/fd/{fd}" for fd in fds], tuple(fds)
    finally:
        for fd in fds:
            os.close(fd)


# SECRETS REPO


def ensure_ready(*tools: str) -> None:
    for tool in ("git", "nix", "sops", *tools):
        if shutil.which(tool) is None:
            raise Abort(f"missing {tool}; run inside `just dev`")
    if not (SECRETS / ".sops.yaml").is_file():
        raise Abort(f"missing secrets repo or sops config at {SECRETS}")
    if run("git", "status", "--porcelain"):
        raise Abort("secrets repo has uncommitted changes; finish or reset those first")
    if run("git", "branch", "--show-current").strip() != "main":
        raise Abort("switch the secrets repo to main first")
    run("git", "fetch", "origin", "main")
    if run("git", "rev-parse", "HEAD") != run("git", "rev-parse", "origin/main"):
        raise Abort("secrets repo main is not synced with origin/main")


def sops_path(*keys: str) -> str:
    return "".join(f"[{json.dumps(key)}]" for key in keys)


def decrypt(file: str) -> dict:
    return json.loads(run("sops", "decrypt", "--output-type", "json", file))


def lookup(data: dict, *keys: str) -> object:
    """Return the value at keys, or None if a key is missing.

    Aborts if a parent key exists but holds a plain value instead of a
    mapping, because `sops set` would replace that value.
    """
    value: object = data
    for depth, key in enumerate(keys):
        if value is None:
            return None
        if not isinstance(value, dict):
            raise Abort(f"{sops_path(*keys[:depth])} holds a value, not a mapping; refusing to replace it")
        value = value.get(key)
    return value


def store(file: str, value: str, *keys: str) -> None:
    run("sops", "set", "--value-stdin", file, sops_path(*keys), input=json.dumps(value))


def publish(message: str, expected: list[str]) -> None:
    status = run("git", "status", "--porcelain", "--untracked-files=all")
    changed = {line[3:] for line in status.splitlines()}
    if changed != set(expected):
        raise Abort(f"unexpected changes in secrets repo, refusing to commit: {sorted(changed ^ set(expected))}")
    run("git", "add", "--", *expected)
    run("git", "diff", "--cached", "--check")
    run("git", "commit", "--message", message)
    run("git", "push", "origin", "main")
    run("nix", "flake", "update", "my-secrets", cwd=NUNIX)
    print(f"Published: {message}")


def require_file(file: str) -> None:
    if not (SECRETS / file).is_file():
        raise Abort(f"missing {file} in secrets repo")


# INVENTORY


def inventory() -> dict:
    apply = "n: { inherit (n.grpcStore) host trustedHosts; domain = n.tailnetDomain; tailscale = n.hosts.${n.grpcStore.host}.tailscale; }"
    attr = f".#nixosConfigurations.{socket.gethostname()}.config.nunix"
    return json.loads(run("nix", "eval", "--json", attr, "--apply", apply, cwd=NUNIX))


# CERTIFICATES

CA_CONFIG = """\
[req]
distinguished_name = dn
x509_extensions = ca
prompt = no
[dn]
CN = nunix nix-grpc-store CA
[ca]
basicConstraints = critical,CA:TRUE,pathlen:0
keyUsage = critical,keyCertSign,cRLSign
subjectKeyIdentifier = hash
"""


def new_key() -> str:
    return run("openssl", "genpkey", "-algorithm", "EC", "-pkeyopt", "ec_paramgen_curve:P-256")


def new_ca(ca_key: str) -> str:
    with pipes(ca_key, CA_CONFIG) as ((key, config), fds):
        return run("openssl", "req", "-x509", "-new", "-sha256", "-days", "3650", "-key", key, "-config", config, fds=fds)


def issue(ca_key: str, ca_cert: str, cn: str, usage: str) -> tuple[str, str]:
    """Return a new key and its CA-signed certificate for cn."""
    key = new_key()
    extensions = "\n".join(
        [
            "basicConstraints = critical,CA:FALSE",
            "keyUsage = critical,digitalSignature",
            "subjectKeyIdentifier = hash",
            "authorityKeyIdentifier = keyid",
            usage,
        ]
    )
    with pipes(key) as ((key_path,), fds):
        request = run("openssl", "req", "-new", "-key", key_path, "-subj", f"/CN={cn}", fds=fds)
    serial = f"0x{secrets.randbits(127) | 1:x}"
    with pipes(ca_key, ca_cert, extensions) as ((ca_key_path, ca_path, ext_path), fds):
        cert = run(
            "openssl", "x509", "-req", "-sha256", "-days", "1825", "-set_serial", serial,
            "-CA", ca_path, "-CAkey", ca_key_path, "-extfile", ext_path,
            input=request, fds=fds,
        )  # fmt: skip
    return key, cert


def write_public(name: str, content: str) -> str:
    path = f"{CERTS}/{name}"
    if (SECRETS / path).exists():
        raise Abort(f"{path} already exists; refusing to overwrite")
    (SECRETS / CERTS).mkdir(exist_ok=True)
    (SECRETS / path).write_text(content)
    return path


# COMMANDS


def oidc(app: str, host: str) -> None:
    file = f"{host}/secrets.yaml"
    require_file(file)
    data = decrypt(file)
    # Reject partial and complete pairs alike
    if any(lookup(data, app, key) is not None for key in ("oidc_client_id", "oidc_client_secret")):
        raise Abort(f"OIDC credentials already exist for {app} on {host}; refusing to overwrite")
    store(file, secrets.token_hex(16), app, "oidc_client_id")
    store(file, secrets.token_hex(32), app, "oidc_client_secret")
    publish(f"Add {app} OIDC credentials for {host}", [file])


def grpc_init() -> None:
    nunix = inventory()
    daemon = nunix["host"]
    # Only the servers and admin can decrypt server/secrets.yaml
    daemon_file, server_file = f"{daemon}/secrets.yaml", "server/secrets.yaml"
    for file in (daemon_file, server_file):
        require_file(file)
        if lookup(decrypt(file), "nix-grpc-store") is not None:
            raise Abort(f"nix-grpc-store secrets already exist in {file}; refusing to overwrite")

    ca_key = new_key()
    ca_cert = new_ca(ca_key)
    tailscale = nunix["tailscale"]
    names = f"DNS:{daemon},DNS:{daemon}.{nunix['domain']},IP:{tailscale['ipv4']},IP:{tailscale['ipv6']}"
    daemon_key, daemon_cert = issue(ca_key, ca_cert, daemon, f"extendedKeyUsage = serverAuth\nsubjectAltName = {names}")
    read_only_key, read_only_cert = issue(ca_key, ca_cert, "read-only", "extendedKeyUsage = clientAuth")
    signing_key = run("nix", "key", "generate-secret", "--key-name", f"{daemon}-1")
    signing_public = run("nix", "key", "convert-secret-to-public", input=signing_key)

    public = [
        write_public("ca.crt", ca_cert),
        write_public(f"{daemon}.crt", daemon_cert),
        write_public("read-only.crt", read_only_cert),
        write_public("signing-key.pub", signing_public),
    ]
    # The CA key is never declared as a sops secret, so no host decrypts it
    store(daemon_file, ca_key, "nix-grpc-store", "ca_key")
    store(daemon_file, signing_key, "nix-grpc-store", "signing_key")
    store(daemon_file, daemon_key, "nix-grpc-store", "tls_key")
    store(server_file, read_only_key, "nix-grpc-store", "read_only_key")
    publish("Add nix-grpc-store CA and credentials", [daemon_file, server_file, *public])


def grpc_cert(host: str) -> None:
    nunix = inventory()
    if host not in nunix["trustedHosts"]:
        raise Abort(f"{host} is not in nunix.grpcStore.trustedHosts")
    file = f"{host}/secrets.yaml"
    require_file(file)
    if lookup(decrypt(file), "nix-grpc-store", "tls_key") is not None:
        raise Abort(f"nix-grpc-store key already exists for {host}; refusing to overwrite")

    daemon_file = f"{nunix['host']}/secrets.yaml"
    ca_key = run("sops", "decrypt", "--extract", sops_path("nix-grpc-store", "ca_key"), daemon_file)
    ca_cert = (SECRETS / CERTS / "ca.crt").read_text()
    key, cert = issue(ca_key, ca_cert, host, "extendedKeyUsage = clientAuth")

    public = write_public(f"{host}.crt", cert)
    store(file, key, "nix-grpc-store", "tls_key")
    publish(f"Add nix-grpc-store credentials for {host}", [file, public])


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)
    oidc_parser = commands.add_parser("oidc", help="generate an app's OIDC client id and secret")
    oidc_parser.add_argument("app")
    oidc_parser.add_argument("host")
    commands.add_parser("grpc-init", help="create the nix-grpc-store CA, daemon and read-only credentials")
    cert_parser = commands.add_parser("grpc-cert", help="issue a trusted host's nix-grpc-store credentials")
    cert_parser.add_argument("host")
    args = parser.parse_args()

    try:
        for name in ("app", "host"):
            if hasattr(args, name) and not NAME.fullmatch(getattr(args, name)):
                raise Abort("names must be non-empty and contain only letters, numbers, hyphens and underscores")
        # Only certificate issuance needs openssl
        tools = () if args.command == "oidc" else ("openssl",)
        ensure_ready(*tools)
        if args.command == "oidc":
            oidc(args.app, args.host)
        elif args.command == "grpc-init":
            grpc_init()
        else:
            grpc_cert(args.host)
    except Abort as error:
        sys.exit(f"error: {error}")


if __name__ == "__main__":
    main()
