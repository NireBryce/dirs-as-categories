# List the recipes
default:
    @just --list

# nix flake check: the main fixture, every error fixture, the template
check:
    nix flake check

# Each error fixture's message (a Nix check can only see that it failed)
errors:
    python3 tests/errors.py

# statix and deadnix over the Nix code (fixtures excluded: some are wrong on purpose)
lint:
    nix shell nixpkgs#statix nixpkgs#deadnix -c sh -c 'statix check . && deadnix --fail --exclude tests/fixtures -- .'

# Everything CI runs
preflight: check errors lint
