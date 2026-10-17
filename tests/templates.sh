#!/usr/bin/env bash
# Evaluate each template's host with real nixpkgs (and home-manager), using
# this checkout's dirs-as-categories:  just templates
#
# `nix flake check` checks only the templates' trees, because building a
# host needs nixpkgs. This needs the network, and takes the inputs each
# template's flake.nix names at their latest, as `nix flake init` would --
# so it catches an option that nixpkgs or Home Manager renamed.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
scratch="$(mktemp -d)"
trap 'rm -rf -- "${scratch:?}"' EXIT

# template:host
for pair in default:example home-manager:laptop; do
    template="${pair%%:*}" host="${pair##*:}"
    cp -r "$root/templates/$template" "$scratch/$template"
    drv="$(nix eval --raw --no-write-lock-file \
        --override-input dirs-as-categories "path:$root" \
        "path:$scratch/$template#nixosConfigurations.$host.config.system.build.toplevel.drvPath")"
    echo "PASS  templates/$template  $host -> $drv"
done
