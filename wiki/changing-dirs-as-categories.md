# Changing dirs-as-categories

_Last modified: 2026-10-17_

This page is for someone changing dirs-as-categories itself: fixing a bug,
adding a rule, improving an error message. It covers the development
shell, the checks, and the test-first loop every change follows. Agents
have the same procedure as skills under `.agents/skills/`
(`change-a-rule`, `review`, `ship`); this page is the version for people.

dirs-as-categories is **experimental**: a change may break flakes that
use it, and the [CHANGELOG](../CHANGELOG.md) says how.

## Contents

- [Quick facts](#quick-facts)
- [Setting up](#setting-up)
- [Where things are](#where-things-are)
- [The loop: test, change, check](#the-loop-test-change-check)
- [Adding an error](#adding-an-error)
- [Before you open a pull request](#before-you-open-a-pull-request)

## Quick facts

| You want to | Run |
|---|---|
| a shell with every tool | `nix develop ./dev` |
| everything CI runs | `just preflight` |
| see how the main fixture's result changed | `just expected-diff` |
| record the new result | `just expected-accept` |
| start an error fixture | `just new-error <name> '<message>'` |
| check the docs | `just docs` |
| evaluate the templates' hosts with real nixpkgs | `just templates` |

## Setting up

```sh
git clone https://github.com/NireBryce/dirs-as-categories
cd dirs-as-categories
nix develop ./dev     # just, python3, statix, deadnix, nixd
just preflight
```

In VS Code, the recommended extension (Nix IDE) uses `nixd` from the
development shell for completion and errors as you type; start VS Code
from inside `nix develop ./dev` so it finds `nixd`.

The development shell is a flake of its own, in `dev/`, so a flake using
dirs-as-categories never inherits its nixpkgs input.

**Run `git add` on every new file before any check.** A flake sees only
the files git knows, so an untracked fixture doesn't exist to
`nix flake check`. `just docs` fails while anything under `nix/`, `tests/`
or `templates/` is untracked.

## Where things are

Read [`../nix/README.md`](../nix/README.md) first: it shows how the four
files in `nix/` fit together and explains the Nix they use. In short:

| Path | Holds |
|---|---|
| `nix/scan.nix` | every rule: what each file is, which folders are categories, every error. Never reads `config` |
| `nix/module.nix` | builds `flake.modules` from the scan |
| `nix/publish.nix` | builds `flake.moduleGraph` |
| `tests/fixtures/main/` | one tree exercising every behaviour; `tests/expected/main.json` is its result |
| `tests/fixtures/err-*/` | one tree per error; `tests/errors.json` holds the message each must produce |
| `templates/` | the starters `nix flake init -t` copies; `nix flake check` checks their trees |

## The loop: test, change, check

1. **Write the case first.** For a behaviour, add files to
   `tests/fixtures/main/modules/` whose `probe` strings show it. For an
   error, see [below](#adding-an-error).
2. **Watch the case fail** against the current code: `just check`, or
   `just errors` for an error.
3. **Change the code.**
4. **Read the difference.** `just expected-diff` shows every line of
   `tests/expected/main.json` your change moves. Each one should be a
   difference you meant; then `just expected-accept`.
5. **Break it on purpose.** Undo the core of your change and confirm that
   a check fails, and that it fails because of what you undid.
6. **Fix the docs in the same change**: the rule in
   `doc/convention.md`, a published field in `doc/format.md`, the guide in
   `wiki/`, and a line in the [CHANGELOG](../CHANGELOG.md).

## Adding an error

```sh
just new-error typo-only 'a/c/one/y.nix: unknown key `nixOS` (did you mean `nixos`?)'
```

The recipe creates `tests/fixtures/err-typo-only/modules/a/c/one/x.nix`
(one valid module) and adds the message to `tests/errors.json`. Make the
tree wrong in exactly one way, `git add` it, and run `just errors`: the
new case fails until the code raises that message. `tests/errors.json`
holds a part of the message; the real one must contain it.

Each error then needs a row in two tables, or `just docs` fails: the
errors table in [`../doc/convention.md`](../doc/convention.md#errors), and
the fixes table in
[Using the flake](using-the-flake.md#when-evaluation-stops). Write the
message so it says how to fix the mistake, not only what the mistake is.

## Before you open a pull request

- `just preflight` passes. CI runs the same recipe on Linux and macOS.
- For a change a template could notice, `just templates` passes too.
- The pull request fills in the template's sections, including
  **Breaks**.
- The [CHANGELOG](../CHANGELOG.md)'s `Unreleased` section says what
  changed, and under **Breaks**, what a flake using dirs-as-categories has
  to change.
- A change to `flake.moduleGraph` follows
  [`../doc/format.md`](../doc/format.md): adding a field is fine; removing,
  renaming or changing one increments `version`.
