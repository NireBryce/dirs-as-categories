---
name: update-inputs
description: How to update this repository's flake inputs (import-tree, flake-parts, the dev shell's nixpkgs) and check nothing moved.
when_to_use: Asked to bump, update or refresh flake.lock or dev/flake.lock.
---

# Updating the inputs

## Applies to

Changing `flake.lock` (import-tree, flake-parts and the nixpkgs-lib inside
it) or `dev/flake.lock` (the development shell's nixpkgs). Not the
templates: they have no lock file, and a user's `nix flake init` locks
theirs.

## Two lock files, two commits

The main flake's lock decides what the tests run against; the dev shell's
only which tools are in `nix develop ./dev`. Update them separately, so a
failure points at one:

```sh
nix flake update                     # flake.lock
nix flake update --flake ./dev       # dev/flake.lock
```

## What to look at

1. **What changed upstream**: `git diff flake.lock` names the old and new
   revisions. Read import-tree's and flake-parts' commits between them for
   anything about file filtering (`pipeTo`, `_` paths), module arguments,
   `flake.modules` or `flakeModules.modules`. Say what you read, or that
   you didn't.
2. **`just preflight`**, then `just expected-diff`: an input update should
   move nothing. A difference is a finding to explain, never something to
   accept.
3. **The `lib` functions `nix/` uses** still exist: `nix/README.md`'s
   tables list them.
4. **A template host still evaluates** when flake-parts or import-tree
   changed (skill `change-a-rule`, its templates step).

## Then

The commit message names each input's old and new revision and what was
verified. A behaviour change upstream that reaches users goes in
`CHANGELOG.md`.
