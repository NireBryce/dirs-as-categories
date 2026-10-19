#!/usr/bin/env bash
# Evaluate each example flake's host with real nixpkgs (and home-manager),
# using this checkout's dirs-as-categories:  just examples
#
# `nix flake check` checks only the examples' trees, because building a
# host needs nixpkgs. This needs the network, and takes the inputs each
# example's flake.nix names at their latest (the examples have no lock
# file) -- so it catches an option that nixpkgs or Home Manager renamed.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
# pwd -P: on macOS mktemp's /tmp is a symlink, and Nix won't read through one
scratch="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf -- "${scratch:?}"' EXIT

# example:host
for pair in default:example home-manager:laptop; do
    example="${pair%%:*}" host="${pair##*:}"
    cp -r "$root/example-flake/$example" "$scratch/$example"
    drv="$(nix eval --raw --no-write-lock-file \
        --override-input dirs-as-categories "path:$root" \
        "path:$scratch/$example#nixosConfigurations.$host.config.system.build.toplevel.drvPath")"
    echo "PASS  example-flake/$example  $host -> $drv"
done
