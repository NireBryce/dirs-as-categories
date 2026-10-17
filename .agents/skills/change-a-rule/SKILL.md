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
   from which file). An error: `just new-error <name> '<message>'` starts
   a `tests/fixtures/err-<name>/` tree and its `tests/errors.json` entry;
   edit the tree so it makes exactly one mistake, and `git add` it.
2. **Watch it fail** against the current code (`nix flake check`, `python3
   tests/errors.py`).
3. Change the code.
4. **Diff the result before recording it.** `just expected-diff`: every
   difference must be one you meant. Then `just expected-accept`. Never
   record output you haven't read.
5. **Break it on purpose**: undo the core of your change and confirm a check
   fails *for that reason* -- not because the mutation made something else
   invalid.

## Then

- `doc/convention.md`: the rule, and its error in the errors table; a new
  error also needs a row in the wiki's "When evaluation stops" table
  (`just docs` fails until both exist).
- `doc/format.md` and `doc/format.schema.json` if a published field
  changed (`just schema` fails until both agree with the graph).
- `README.md` if a user would notice.
- **A breaking change to `flake.moduleGraph`** (a field removed, renamed or
  changed in meaning) increments `version` and says so in `doc/format.md`;
  readers such as flake-module-graph refuse a version they don't know.
  Adding a field is not breaking.
- The templates (`templates/default`, `templates/home-manager`) must still
  be working flakes: `nix flake check` covers their trees; evaluate a host
  from one when the change could affect it, with
  `--override-input dirs-as-categories path:<this checkout>` (the template
  points at GitHub).
- `just preflight`.

## Keep the code readable

`nix/` is written for readers who don't know Nix (`nix/README.md`). Give
a new binding a name that says what it holds, a comment with an example
value when the shape isn't obvious, and split an expression that does
several things into named steps. A new piece of Nix syntax or a `lib`
function the code didn't use before goes in `nix/README.md`'s tables.
