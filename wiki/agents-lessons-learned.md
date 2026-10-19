# Lessons agents learned the hard way
_Last modified: 2026-10-19_

This page collects what surprised agent sessions about Nix, flake-parts and
this repository's inputs, so the next session doesn't relearn it. Each
lesson says what happened, the rule to follow, and how the lesson was
checked. Skill `record-a-lesson` adds to this page.

## Contents

- [Evaluating without GitHub tarballs](#evaluating-without-github-tarballs)
- [Probing a tree outside the flake](#probing-a-tree-outside-the-flake)
- [Options declared by a module imported twice](#options-declared-by-a-module-imported-twice)
- [What `builtins.tryEval` catches](#what-builtinstryeval-catches)
- [Calling a user's file early](#calling-a-users-file-early)

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

  The same file imports cleanly into flake-parts directly. On 2026-10-19
  `canCallEarly` in `nix/scan.nix` treated such a function as callable
  early.
- Each early call evaluates the file's top level once more. A
  `builtins.trace` there prints twice, once from the scan and once from
  flake-parts.

Checked on 2026-10-19 with probe trees in a scratch directory.
