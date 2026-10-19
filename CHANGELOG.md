# Changelog

This file lists what changed for a flake using dirs-as-categories, newest
first. dirs-as-categories is **experimental** (see the
[README](README.md)), so any release may break a flake: **Breaks** says
what you have to change. Pin a release tag
(`github:NireBryce/dirs-as-categories/v0.2.0`) and read the entries
between yours and the one you move to. Until `1.0`, a release that
breaks something increments the minor number (`v0.2.0`); one that breaks
nothing increments the patch number (`v0.1.1`). Error messages' wording
is not part of what a release keeps; their meaning is.

## Unreleased

### Fixed

- A flake that imports a tree twice, or two trees that don't refer to each
  other, evaluates again. Before,
  each import declared `dirsAsCategories.checkOrphans` and
  `flake.moduleGraph` again, so every `checks.<system>` and
  `flake.moduleGraph` stopped with ``The option `…' … is already
  declared``. A tree imported twice now loads once; with two trees,
  reading `flake.moduleGraph` stops with
  `flake.moduleGraph describes one modules tree`, because the format
  describes one tree.
- A flake-parts module written `args: …` that hands its arguments on
  (`args: import ./_hosts.nix args`) loads as a flake-parts module. Before,
  dirs-as-categories called it with only `lib` and `inputs`, and evaluation
  stopped with `called without required argument`.

## v0.2.0 — 2026-10-18

A flake on `v0.1.1` may have to change: read **Breaks**.

### Breaks

- `nix flake init -t github:NireBryce/dirs-as-categories` no longer
  works: the flake has no templates. dirs-as-categories is for a flake
  you already have; the wiki's "Setting it up" walks through adding it.
  The example trees moved to `example-flake/`, to read and evaluate, and
  the wiki's new "How it works, on the example flake" walks through one.
- A module file named `outPath.nix`, or a category folder named `outPath`,
  is now an error: `` `outPath` can't be a name ``. Before, it evaluated,
  but `flake.moduleGraph.modules` held only that module's record, because
  Nix reads a set with an `outPath` as a path. Rename the file or folder.
- The `key` of every module dirs-as-categories creates now names the
  tree's root. A configuration that set one of these keys itself, to stop
  a module loading, no longer matches it.

### Fixed

- Two trees imported into one flake that both have a module with the same
  name (say `ssh`) now both reach a configuration that includes it. Before,
  the module system kept the first and silently dropped the other, because
  their keys were the same.
- The example flakes' `ssh.nix` also sets `KbdInteractiveAuthentication = false`.
  With only `PasswordAuthentication = false`, sshd still accepted
  passwords through keyboard-interactive login.
- The wiki says that a leading `_` hides a file only from
  dirs-as-categories: every file git tracks is copied to the
  world-readable `/nix/store`, so secrets stay out of the tree.

## v0.1.1 — 2026-10-18

Nothing breaks: a flake on `v0.1.0` can move to this release unchanged.

### Added

- The README's "Requirements" section names the oldest Nix (2.18),
  flake-parts (`d50b490`, 2024-09-12) and import-tree (`4ebb10a`,
  2026-07-16) dirs-as-categories works with, and CI tests them.
- Evaluation stays fast in a large tree: 2,000 modules evaluate in about
  0.6 s, where they took about 11 s, and time now grows in proportion to
  the tree (issue 6). Results are unchanged.
- `doc/format.schema.json`: `flake.moduleGraph`'s format as a JSON Schema,
  for tools that read the graph.

## v0.1.0 — 2026-10-17

The first tagged release. Changes before it are in the git log only; the
entries below are what changed since the commit before it, `f2c4494`.

### Added

- `lib.tree.addClasses [ "nixOnDroid" ]` adds classes to the defaults;
  `lib.tree.withClasses` still replaces them.
- A second template: `nix flake init -t github:NireBryce/dirs-as-categories#home-manager`,
  a NixOS host with Home Manager. Both templates now include a README
  with the next steps.
- Errors that say how to fix the mistake:
  - `{ pkgs, ... }:` or `{ config, ... }:` at the top of a module file:
    move the arguments into the class.
  - A NixOS module, such as `hardware-configuration.nix`, in the tree:
    rename it `_…` and import it from a class.
  - A near miss of a class or reserved key (`nixOS`, `home-manager`,
    `include`), even as a file's only key: "did you mean `nixos`?".
  - An unknown name in `includes` or `enables` suggests a close one, or
    says the name is a plain folder's.
  - A flake without `flake-parts.flakeModules.modules` says to import it.
    Before, a flake without it ended in `infinite recursion encountered`
    once another file defined `flake.modules`.
- Release tags, from this one on. The README, the wiki and both templates
  pin `v0.1.0`.

### Breaks

- A file in the tree that asks for `pkgs`, `modulesPath`, `osConfig`,
  `nixosConfig`, `darwinConfig` or `utils` without a default is now an
  error, even when it is a flake-parts module that sets
  `_module.args.pkgs` itself. Rename such a file with a leading `_` and
  import it where it is needed.
- A set whose key is a near miss of a class or reserved key (`nixOS`,
  `Darwin`, `include`) is now an error rather than a flake-parts module.
- A flake that doesn't import `flake-parts.flakeModules.modules` stops
  with an error when anything reads `flake.modules`.
- Several error messages are longer: they now end with advice. A script
  that matches a whole message may need updating.

### No change for users

- The code in `nix/` is rewritten to be readable without knowing Nix, and
  `nix/README.md` explains it. Behaviour is unchanged.
