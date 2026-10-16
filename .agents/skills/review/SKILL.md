---
name: review
description: How to review a change to dirs-as-categories -- the checks to run and the failure modes a generic reviewer doesn't know.
when_to_use: Review a PR, branch, or commit here, or before saying done on your own change.
---

# Reviewing a change

## Applies to

Reviewing a PR, branch or commit here, yours or another's, or the last
step before saying "done".

## Run first

1. `git status --short` -- an untracked fixture doesn't exist to the flake.
2. `just preflight` -- flake check (main fixture, error fixtures,
   template), every error message, lint.
3. `nix eval --json .#tests.main` against `tests/expected/main.json` if the
   expected result changed: is every difference one the change meant?

## Read for

- **Anything in `nix/scan.nix` reading `config`**, directly or through a
  function it calls -- an infinite recursion waiting for the right tree.
- **A new behaviour without a fixture**, or a new error without an
  `err-*` tree and a message in `tests/errors.json`.
- **A check that was never seen failing.** Ask how it was broken on purpose.
- **Expected output recorded wholesale**: `tests/expected/main.json` changed
  in lines the description doesn't explain.
- **`flake.moduleGraph` changed** without `doc/format.md`, or a breaking
  change without a `version` bump.
- **A rule changed** without `doc/convention.md` (its errors table too).
- **Examples naming real machines or people** (`doc/style.md`).
- **Public text about a security fix** that says what got past the old
  version instead of what is now enforced.

## Saying the outcome

"Evaluates", "`nix flake check` passes" and "CI is green" are different
claims; say which you saw.
