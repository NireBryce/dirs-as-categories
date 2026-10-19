# Lessons agents learned the hard way
_Last modified: 2026-10-19_

This page collects what surprised agent sessions about Nix, flake-parts and
this repository's inputs, so the next session doesn't relearn it. Each
lesson says what happened, the rule to follow, and how the lesson was
checked. Skill `record-a-lesson` adds to this page.

## Contents

- [Evaluating without GitHub tarballs](#evaluating-without-github-tarballs)
- [Probing a tree outside the flake](#probing-a-tree-outside-the-flake)
- [Running the linters without the dev shell](#running-the-linters-without-the-dev-shell)
- [Options declared by a module imported twice](#options-declared-by-a-module-imported-twice)
- [What `builtins.tryEval` catches](#what-builtinstryeval-catches)
- [Calling a user's file early](#calling-a-users-file-early)
- [A flake-parts module's keys can't depend on `config`](#a-flake-parts-modules-keys-cant-depend-on-config)
- [Comparing two `tryEval` results](#comparing-two-tryeval-results)
- [A probe tree follows the convention too](#a-probe-tree-follows-the-convention-too)
- [Test a combination the way a user combines](#test-a-combination-the-way-a-user-combines)

## Evaluating without GitHub tarballs

In a cloud session, `nix eval .#…` fails before evaluating anything:

```
error: unable to download 'https://github.com/hercules-ci/flake-parts/archive/<rev>.tar.gz': HTTP error 403
```

Nix fetches a `github:` input as a tarball, which the session's proxy
refuses; the same proxy serves anonymous `git` reads of public repositories.
Fetch each locked revision with git, and point the inputs at the clones --
including flake-parts' own `nixpkgs-lib`, which is a nested input:

```sh
deps=<scratch>/deps
for spec in "hercules-ci/flake-parts <rev>" "denful/import-tree <rev>" "nix-community/nixpkgs.lib <rev>"; do
    set -- $spec; dir=$deps/$(basename $1)
    git init -q $dir && git -C $dir fetch -q --depth 1 https://github.com/$1 $2 && git -C $dir checkout -q FETCH_HEAD
done
nix eval .#checks.x86_64-linux --apply builtins.attrNames \
    --override-input flake-parts path:$deps/flake-parts \
    --override-input flake-parts/nixpkgs-lib path:$deps/nixpkgs.lib \
    --override-input import-tree path:$deps/import-tree
```

The revisions are the `rev` fields in `flake.lock`. Nix reports a
different `narHash` for each override, because a `path:` input includes the
clone's `.git`; the evaluation is the same. `nix eval` with overrides left
`flake.lock` unchanged. Checked on 2026-10-19 with Nix 2.34.6.

## Probing a tree outside the flake

`builtins.getFlake` takes no `--override-input`, so a scratch expression
can't reach the inputs through it in the session above. Import each input
by hand instead. flake-parts' `lib.nix` needs arguments only its
`flake.nix` supplies, so call the outputs function:

```nix
let
    repo = /home/user/dirs-as-categories;   # this checkout
    deps = /tmp/deps;                       # where the clones above live
    lib  = import (deps + "/nixpkgs.lib/lib");
    fp   = (import (deps + "/flake-parts/flake.nix")).outputs {
        self        = fp;
        nixpkgs-lib = { inherit lib; outPath = deps + "/nixpkgs.lib"; };
    };
    tree = import (repo + "/nix") { importTree = import (deps + "/import-tree"); };
in
fp.lib.mkFlake { inputs = { self = { outPath = repo; }; flake-parts = fp; }; } {
    systems = [ "x86_64-linux" ];
    imports = [ fp.flakeModules.modules (tree (repo + "/tests/fixtures/main/modules")) ];
}
```

Files read this way by path are not part of a flake, so a probe tree in the
scratch directory needs no `git add`; the rule in `AGENTS.md` applies to
fixtures under `tests/`. Run the file with
`nix eval --impure --file <file> <attribute>`. Checked on 2026-10-19 with
flake-parts `024633c`.

## Running the linters without the dev shell

`nix develop ./dev` needs nixpkgs as a GitHub tarball, which the cloud
session's proxy refuses, so `just lint` can't run there. On 2026-10-19
that let a push fail CI with statix's
`[20] Warning: Avoid repeated keys in attribute sets`: `nix/shared.nix`
assigned `options.…` three times at the top level.

The binary cache is reachable even when GitHub tarballs are not. Fetch
the nixpkgs revision `dev/flake.lock` pins with git, then build the tools
from it; Nix copies them from `cache.nixos.org` instead of compiling:

```sh
git init -q <scratch>/nixpkgs
git -C <scratch>/nixpkgs fetch -q --depth 1 https://github.com/NixOS/nixpkgs <rev from dev/flake.lock>
git -C <scratch>/nixpkgs checkout -q FETCH_HEAD
nix build --no-link --print-out-paths -f <scratch>/nixpkgs statix deadnix
```

Then run `statix check .` and `deadnix --fail --exclude tests/fixtures -- .`
from those store paths, as `just lint` does. Statix flagged the key
assigned three times, not the two `options.…` that `nix/module.nix` had
before; group repeated keys into one set (`options = { … };`) either way.
Checked on 2026-10-19 with statix 0.5.8 and deadnix 1.3.2.

## Options declared by a module imported twice

The module system raises an error when two modules declare one option:

```
error: The option `dirsAsCategories.checkOrphans' in `…/a/modules (dirs-as-categories)' is already declared in `…/b/modules (dirs-as-categories)'.
```

Nix raises the error only when something reads that option. Importing a
module twice is therefore safe for an option nobody reads and broken for
any other. A module without a `key` declares its options once per import;
a `key` makes the module system load it once.

Two traps follow for tests:

- A test that reads only `flake.modules` never reads the other options,
  and passes. On 2026-10-19 the `two-trees` test passed while reading
  `flake.moduleGraph` of the same flake failed.
- `systems = [ ]` evaluates no `perSystem`, so an error that only a
  per-system output reaches never appears. Give a test that should cover
  `checks` or `packages` at least one system.

Checked on 2026-10-19 by importing `tests/fixtures/two-trees/a/modules`
twice with `systems = [ "x86_64-linux" ]`.

## What `builtins.tryEval` catches

`builtins.tryEval` catches only `throw` and a failed `assert`. Every other
error stops evaluation, `tryEval` or not:

| Expression | Result of `(builtins.tryEval …).success` |
|---|---|
| `throw "x"` | `false` |
| `assert false; 1` | `false` |
| `({ a }: a) { }` (missing argument) | error |
| `{ }.a` (missing attribute) | error |
| `"x" + 1` (type error) | error |
| `abort "x"` | error |

Code that calls a user's function to look at the result must make every
stand-in it passes `throw`, and must not pass too few arguments: the
second is an error `tryEval` can't catch. Checked on 2026-10-19 with
Nix 2.34.6.

## Calling a user's file early

`nix/scan.nix` calls some user files before `config` exists, to read their
keys. Two Nix facts decide what such a call can do:

- `builtins.functionArgs` returns `{ }` for both `args: …` and
  `{ ... }@args: …`. Nix can't tell what such a function will read, so a
  call with only `lib` and `inputs` fails as soon as the function forwards
  its argument to one that needs `config`:

  ```
  error: function 'anonymous lambda' called without required argument 'config'
  ```

  The same file imports cleanly into flake-parts directly. Until
  2026-10-19 `callEarly` in `nix/scan.nix` called such a function with
  only `lib` and `inputs`; it now passes throwing stand-ins (`openCall`).
- Each early call evaluates the file's top level once more. A
  `builtins.trace` there prints twice, once from the scan and once from
  flake-parts.

Checked on 2026-10-19 with probe trees in a scratch directory.

## A flake-parts module's keys can't depend on `config`

A fixture meant to show a module whose keys `nix/scan.nix` can't see
stopped evaluation in flake-parts itself:

```
error: infinite recursion encountered
```

The module system reads every module's top-level keys (`imports`,
`options`, `config`) before `config` exists. A module that builds its
top level from `config`, such as
`{ config, lib, ... }: lib.optionalAttrs (config.systems != [ ]) { … }`,
is never valid, with or without dirs-as-categories. To hide a module's
keys from the scan in a valid way, make them depend on `self`, a
flake-parts argument that exists early but is a stand-in during the scan
(`tests/fixtures/main/modules/general/_wrapped.nix`). Checked on
2026-10-19.

## Comparing two `tryEval` results

`(builtins.tryEval e).value` is `false` whenever `e` throws, so a test
written `evaluates a == evaluates b` passes when both `a` and `b` fail. On
2026-10-19 the first draft of the `two-trees-checks` test in
`tests/default.nix` compared the graph of a tree imported twice with the
graph of the tree imported once, and both failed. Check that one side
succeeds before comparing:

```nix
let
    evaluates = value: (builtins.tryEval (builtins.deepSeq value value)).value;
    once      = evaluates (throw "both fail");
in
once != false && evaluates (throw "both fail") == once   # false, as it should be
```

Checked on 2026-10-19 with Nix 2.34.6.

## A probe tree follows the convention too

A scratch tree written to test two trees together stopped with an error
that had nothing to do with two trees:

```
error: dirs-as-categories: hosts/laptop.nix: includes.nixos: unknown name `desktop` (general/desktop is a plain folder, which has no name; make the folder a category with folderIsCategory = true)
```

The tree held `general/desktop/plasma.nix`. A folder is a category only
when a module sits in a subfolder below it
([convention](../doc/convention.md)), so `general/desktop` was a plain
folder. Lay a probe tree out as the example flakes do, one folder per
module (`general/desktop/plasma/plasma.nix`), and read the error before
blaming the change you are testing. Checked on 2026-10-19.

## Test a combination the way a user combines

The `two-trees` test in `tests/default.nix` has passed since it was added
on 2026-10-18, while the reason anyone would import two trees -- a host in
one tree including a category from another -- stops with
``unknown name `base` ``. The test
imported two trees that never referred to each other, which checks the
mechanism (module `key`s) rather than the use.

When a test covers combining things (two trees, two classes, a tree
imported twice), write the case a user would write, and run the same files
as a single tree as a control: a difference between the two results is
either the feature or a bug. Checked on 2026-10-19 with probe trees in a
scratch directory; the results are in issue 20.
