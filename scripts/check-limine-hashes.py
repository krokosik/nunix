#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3

import hashlib
import re
import os

# Adjust this to your actual ESP mount point
BOOT_DIR = "/boot"
CONF_PATH = os.path.join(BOOT_DIR, "limine/limine.conf")

def get_blake2b(filepath):
    with open(filepath, "rb") as f:
        return hashlib.blake2b(f.read(), digest_size=64).hexdigest()

with open(CONF_PATH, "r") as f:
    config = f.read()

# Match lines like: kernel_path: boot():/nixos/kernel.efi#blake2b:hash
pattern = re.compile(r'(?:kernel|module)_path:\s*(?:boot\(\):)?([^#\s]+)#(?:blake2b:)?([a-f0-9]+)')
matches = pattern.findall(config)

all_good = True

for path, expected_hash in matches:
    # Resolve absolute path on the ESP
    full_path = os.path.join(BOOT_DIR, path.lstrip('/'))
    
    if not os.path.exists(full_path):
        print(f"[FAIL] Missing file: {full_path}")
        all_good = False
        continue

    actual_hash = get_blake2b(full_path)
    
    if actual_hash == expected_hash:
        print(f"[ OK ] {path}")
    else:
        print(f"[FAIL] {path}")
        print(f"       Expected: {expected_hash}")
        print(f"       Actual:   {actual_hash}")
        all_good = False

if all_good:
    print("\nAll Limine checksums match! Safe to reboot.")
else:
    print("\nWARNING: Checksum mismatch detected. Limine will panic on boot.")
    exit(1)
