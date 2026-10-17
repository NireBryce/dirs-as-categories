# Changelog

This file lists what changed for a flake using dirs-as-categories, newest
first. dirs-as-categories is **experimental** (see the
[README](README.md)), so any release may break a flake: **Breaks** says
what you have to change. Pin a release tag
(`github:NireBryce/dirs-as-categories/v0.1.0`) and read the entries
between yours and the one you move to. Until `1.0`, a release that
breaks something increments the minor number (`v0.2.0`); one that breaks
nothing increments the patch number (`v0.1.1`). Error messages' wording
is not part of what a release keeps; their meaning is.

## Unreleased

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
