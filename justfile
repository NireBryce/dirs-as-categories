# List the recipes
default:
    @just --list

# nix flake check: the main fixture, every error fixture, the template
check:
    nix flake check

# Each error fixture's message (a Nix check can only see that it failed)
errors:
    python3 tests/errors.py

# statix and deadnix over the Nix code (fixtures excluded: some are wrong on purpose), actionlint over the workflows
lint:
    nix shell nixpkgs#statix nixpkgs#deadnix nixpkgs#actionlint -c sh -c 'statix check . && deadnix --fail --exclude tests/fixtures -- . && actionlint'

# Mechanical doc checks: skills listed, links resolve, errors documented and tested, nix blocks parse
docs:
    python3 tests/docs.py

# Show how the main fixture's result differs from tests/expected/main.json
expected-diff:
    python3 tests/expected.py diff

# Record the main fixture's result as tests/expected/main.json (read expected-diff first)
expected-accept:
    python3 tests/expected.py accept

# Start an error fixture: just new-error <name> '<expected message>'
new-error name message:
    python3 tests/new_error.py {{quote(name)}} {{quote(message)}}

# Everything CI runs
preflight: check errors docs lint

# Each template's host, evaluated with real nixpkgs and home-manager (network; not in preflight)
templates:
    bash tests/templates.sh
