---
name: review
description: How to review a change to dirs-as-categories -- the checks to run and the failure modes a generic reviewer doesn't know.
when_to_use: Review a PR, branch, or commit here, or before saying done on your own change.
---

# Reviewing a change

## Applies to

Use this skill to review a PR, branch or commit here, yours or another's,
and as the last step before saying "done".

## Run first

1. `git status --short` -- an untracked fixture doesn't exist to the flake.
2. `just preflight` -- flake check (main fixture, error fixtures,
   template), every error message, the doc checks, lint.
3. If `tests/expected/main.json` changed, `git diff origin/main -- tests/expected/`
   and ask of each line: is this a difference the change meant?

## Read for

- **Anything in `nix/scan.nix` reading `config`**, directly or through a
  function it calls: it is an infinite recursion that some tree will hit.
- **A search repeated per file in `nix/scan.nix`** (`elem`, `filter`,
  `lib.unique` inside a `map` over files or folders): `just bench` should
  catch it, but read for it too.
- **A new behaviour without a fixture**, or a new error without an
  `err-*` tree and a message in `tests/errors.json`.
- **A check that was never seen failing.** Ask how the author broke it on
  purpose.
- **Expected output recorded wholesale**: `tests/expected/main.json` has
  changed lines that the description doesn't explain.
- **`flake.moduleGraph` changed** without `doc/format.md` and
  `doc/format.schema.json`, or a breaking
  change to it without a `version` bump.
- **A rule changed** without `doc/convention.md` (its errors table too).
- **A user-visible change** without a `CHANGELOG.md` line, or a break not
  under **Breaks**: a flake that worked before and fails after is a break,
  however small.
- **Examples naming real machines or people** (`doc/style.md`).
- **Public text about a security fix** that says what got past the old
  version instead of what the check now enforces.

## Saying the outcome

"Evaluates", "`nix flake check` passes" and "CI is green" are different
claims; say which you saw.
