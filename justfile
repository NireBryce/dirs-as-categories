# List the recipes
default:
    @just --list

# nix flake check: the main fixture, every error fixture, every example tree
check:
    nix flake check

# Each error fixture's message (a Nix check can only see that it failed)
errors:
    python3 tests/errors.py

# statix and deadnix over the Nix code (fixtures excluded: some are wrong on purpose), actionlint over the workflows (needs the dev shell)
lint:
    statix check . && deadnix --fail --exclude tests/fixtures -- . && actionlint

# zizmor over the workflows and gitleaks over the history: run when auditing or reviewing .github/ (needs the dev shell; not in preflight)
security:
    zizmor -q . && gitleaks git .

# lychee over every link in the Markdown: run with a docs change or a release (needs the dev shell and the network; not in preflight)
links:
    lychee --no-progress --max-retries 2 .

# `nix flake update` for one lock file (flake.lock or dev/flake.lock), then show the lock diff and run expected-diff; you still review the diff and run preflight (skill `update-inputs`; network)
update-inputs lock="flake.lock":
    nix flake update --flake $(dirname {{quote(lock)}})
    git diff --stat {{quote(lock)}}
    just expected-diff

# Mechanical doc checks: skills listed, links resolve, errors documented and tested, nix blocks parse
docs:
    python3 tests/docs.py

# Every published graph the tests build against doc/format.schema.json
schema:
    python3 tests/schema.py

# How evaluation time grows with the tree: 2,000 modules against 500 (fails above 6x)
bench:
    python3 tests/bench.py

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
preflight: check errors docs schema bench lint

# Each example flake's host, evaluated with real nixpkgs and home-manager (network; not in preflight)
examples:
    bash tests/examples.sh
