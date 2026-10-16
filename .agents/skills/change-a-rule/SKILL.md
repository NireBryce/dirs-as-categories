---
name: change-a-rule
description: How to add or change one of dirs-as-categories' rules, keys, errors or published fields, test-first.
when_to_use: Changing how files are read, which folders are categories, a module file key, an error, or flake.moduleGraph.
---

# Changing a rule

## Applies to

Anything under `nix/`: how a file's shape is read, which folders are
categories, a reserved key, `defaults.nix`, an error message, or a field of
`flake.moduleGraph`.

## Where things are

| File | Holds |
|---|---|
| `nix/scan.nix` | every rule: shapes, names, categories, flags, errors. **Never reads `config`.** |
| `nix/module.nix` | builds `flake.modules` from the scan: `includes`, `enables`, `defaults.nix`, `key`s |
| `nix/publish.nix` | `flake.moduleGraph` |
| `doc/convention.md` | every rule and error, stated |
| `doc/format.md` | `flake.moduleGraph`, field by field |
| `tests/fixtures/main/modules/` | one tree exercising every behaviour; `tests/expected/main.json` is its expected result |
| `tests/fixtures/err-*/` | one tree per error; `tests/errors.json` the message each must produce |

## Why nothing in `scan.nix` may read `config`

The scan decides `imports` and the attribute *names* of `flake.modules`.
The module system needs both before `config` exists; reading it there is an
infinite recursion. A file may be called only with `lib` and `inputs` --
both exist first (`inputs` is a flake-parts special argument). `config` is
for values, in `module.nix`, lazily.

## Test first

1. **Write the case first.** A behaviour: add files to the main fixture
   whose `probe` strings show it (what reached which host, how many times,
   from which file). An error: a new `tests/fixtures/err-<name>/` tree and
   its message in `tests/errors.json`.
2. **Watch it fail** against the current code (`nix flake check`, `python3
   tests/errors.py`).
3. Change the code.
4. **Diff the result before recording it.** `nix eval --json .#tests.main`
   against `tests/expected/main.json`: every difference must be one you
   meant. Then write it to `tests/expected/main.json`. Never record output
   you haven't read.
5. **Break it on purpose**: undo the core of your change and confirm a check
   fails *for that reason* -- not because the mutation made something else
   invalid.

## Then

- `doc/convention.md`: the rule, and its error in the errors table.
- `doc/format.md` if a published field changed.
- `README.md` if a user would notice.
- **A breaking change to `flake.moduleGraph`** (a field removed, renamed or
  changed in meaning) increments `version` and says so in `doc/format.md`;
  readers such as flake-module-graph refuse a version they don't know.
  Adding a field is not breaking.
- The template (`templates/default`) must still be a working flake: its
  check in `nix flake check` covers the tree; evaluate a host from it when
  the change could affect one.
- `just preflight`.
