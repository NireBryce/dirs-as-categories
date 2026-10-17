# The convention

This page lists every rule dirs-as-categories applies and every error it
raises. The rules are **experimental** and may change (see the
[README](../README.md)). Paths are relative to the folder you pass to
`lib.tree`.

dirs-as-categories decides everything from file paths and from the shape of
what each file evaluates to, never from `config`. Because of this,
dirs-as-categories can build `imports` and `flake.modules` names without
recursing through the module system.

## Files

import-tree finds the files: every `.nix` file, except paths with a component
starting with `_`. dirs-as-categories then sorts each file by what the file
evaluates to:

| A file that evaluates to | is |
|---|---|
| an attribute set, named `defaults.nix` | a [defaults file](#defaultsnix) |
| any other attribute set with a class or reserved key | a [module file](#module-files) |
| an attribute set with neither (`{ perSystem = …; }`) | a flake-parts module, imported unchanged |
| a function of only `lib` and/or `inputs` that returns a class or reserved key | a module file (or defaults file), called with `lib` and `inputs` |
| a function asking for more than `lib` and `inputs` whose result has a class or reserved key | an error: the arguments belong inside the class |
| a function asking for `pkgs`, `modulesPath`, `osConfig`, `nixosConfig`, `darwinConfig` or `utils` (a NixOS or Home Manager module) | an error |
| any other function | a flake-parts module, imported unchanged |
| anything else | an error |

### Functions of `lib` and `inputs`

A module file can take the flake's `lib` and `inputs`, so the file's body can
use them the way a flake-parts module's body would:

```nix
{ lib, inputs, ... }:
{
    nixos = {
        imports = [ inputs.some-flake.nixosModules.default ];
        services.foo.enable = lib.mkDefault true;
    };
}
```

dirs-as-categories calls such a function to see what the function returns.
The call is safe: both arguments exist before `config` does (`inputs` is a
flake-parts special argument, and flake-parts always passes `lib`), so
reading the result's keys can't recurse through the module system.
dirs-as-categories looks at the function's required arguments:

- If the function requires only `lib` and/or `inputs` (anything else must
  have a default), dirs-as-categories calls the function with just those. If
  the result has a class or reserved key, the file is a module file (or, for
  `defaults.nix`, a defaults file). Otherwise dirs-as-categories imports the
  file unchanged as a flake-parts module, so `{ lib, ... }: { perSystem = …; }`
  stays a flake-parts module.
- If the function requires anything else, such as `config` or `withSystem`,
  the file is a flake-parts module, imported unchanged -- with two
  exceptions, both mistakes. dirs-as-categories calls the function with
  stand-ins for the arguments that don't exist yet; a stand-in throws if
  anything reads it, and dirs-as-categories catches the throw, so `config`
  is never read. If the result's keys can be seen and include a class or
  reserved key (`{ pkgs, ... }: { nixos = …; }`), that is an error: the
  arguments belong inside the class, `nixos = { pkgs, ... }: …`. If the
  function asks for an argument only a NixOS or Home Manager module gets
  (`pkgs`, `modulesPath`, `osConfig`, `nixosConfig`, `darwinConfig`,
  `utils`), the file is a NixOS module, such as a `hardware-configuration.nix`,
  and that is an error too: give the file a leading `_` and import it from
  a class.

A key that differs from a class or reserved key only in case or spelling
(`nixOS`, `home-manager`, `include`) is an error, naming the key it
resembles, even when it is the file's only key. Without that check, such a
file would have no class key and load as a flake-parts module.

## Module files

A module file may use these keys:

| Key | Value |
|---|---|
| a class | that class's module: an attribute set, a function, or a path |
| `includes` | `{ <class> = [ name … ]; }` |
| `enables` | `{ <class> = [ name … ]; }` |
| `folderIsCategory` | `true` or `false` |

The classes are `nixos`, `homeManager` and `darwin`. `lib.tree.addClasses
[ "nixOnDroid" ]` adds to them; `lib.tree.withClasses [ "nixos" ]`
replaces them.

A module file declares the module `<name>` in every class the file has a key
for, and in every class the file has `includes` for. A file with neither
(only `folderIsCategory`) declares nothing.

**Name.** A module's name is its filename without `.nix`. A file named
`default.nix` takes its folder's name instead. A `default.nix` directly in
the tree's root is an error.

**`includes.<class>`.** Each name is a module or category of that class, and
the module imports every name listed. Modules and categories share one
namespace, so a name means one thing.

**`enables.<class>`.** Each name is a module or category of that class.
dirs-as-categories passes each named module to this file's class modules as
the argument `enabled.<class>.<name>`, alongside their usual arguments; a
class module must be a function to receive `enabled`:

```nix
{
    enables.homeManager = [ "my-home" ];
    nixos = { enabled, ... }: {
        home-manager.users.me = enabled.homeManager.my-home;
    };
}
```

`enabled` holds only the names you declare, so the declaration can't drift
from the use. `flake.moduleGraph` records the link.

## Folders and categories

A folder below the top level is a **category** when:

1. a file directly in the folder (a module file or the folder's
   `defaults.nix`) sets `folderIsCategory`, and that value decides; otherwise
2. one of the folder's subfolders, at any depth, holds a module file
   declaring a module.

Top-level folders are **areas**. Areas are never categories; setting
`folderIsCategory = true` in an area is an error.

A category is a module named after its folder, in every class. A category
imports:

- the modules beneath the category that belong to no nested category,
- the categories nested in it that are nested in no other category under it,
- the `defaults.nix` files the category reaches (see below).

So including a category includes everything beneath the category.

A folder that isn't a category is a **plain folder**. A plain folder has no
name, and its modules belong to the nearest category above it.

## defaults.nix

A `defaults.nix` is never a module. The file is an attribute set, or a
function of `lib` and/or `inputs` returning one. A `defaults.nix` may use the
class keys and `folderIsCategory`, which applies to the file's folder as in
any other file.

A `defaults.nix`'s class parts apply whenever a configuration reaches
anything in the file's folder's subtree:

- through the nearest category at or above the folder (so a `defaults.nix`
  in a plain folder moves up to the category that holds the folder), or
- by including any module or category inside the folder directly.

Each `defaults.nix` loads once per configuration, however many routes reach
the file, because every module dirs-as-categories creates carries a `key`.

Definitions keep their file: errors and `options.<x>.definitionsWithLocations`
name `defaults.nix`, not dirs-as-categories.

## Orphans

If no `includes` or `enables` reaches a module inside a category, the
module still evaluates but installs nothing, so evaluation can't report the
module. An `includes` or `enables` reaches a module by naming the module or a
category above it (a category includes everything beneath it). Modules
outside every category are entry points (hosts, home aggregates); nothing is
meant to name entry points, so they are never orphans.

`flake.moduleGraph.orphans` lists the orphans. With

```nix
dirsAsCategories.checkOrphans = true;
```

`nix flake check` also runs `checks.<system>.module-orphans`, which fails
and names each orphan and its path. The check is off by default because it
adds a check to your flake.

## Errors

Each error stops evaluation with `dirs-as-categories: <path>: <what>`.

| Error | Raised when |
|---|---|
| `names used more than once: <name> (<paths>)` | two modules, two categories, or a module and a category share a name (including `x.nix` beside `x/default.nix`) |
| `unknown key` | a module file or `defaults.nix` has a key that isn't allowed, or any file has a near miss of one (`nixOS`); the message suggests the key meant |
| `` asks for <args> at the top of the file, where only `lib` and `inputs` exist `` | a function asking for `config`, `pkgs` or the like returns class keys |
| `asks for <args>, which only a NixOS or Home Manager module gets` | a function asking for `pkgs`, `modulesPath` or the like has no class keys: a NixOS module in the tree |
| `<kind>.<class>: unknown class` | `includes` or `enables` names a class not in the list |
| `<kind>.<class>: unknown name` | a name in `includes`/`enables` isn't a module or category; the message suggests a close name, or says the name is a plain folder's |
| `<kind>.<class>: <name> has no <class> module` | the name exists, but not in that class |
| `files disagree on folderIsCategory` | two files in one folder set different values |
| `folderIsCategory must be true or false` | `folderIsCategory` has any other value |
| `a top-level folder is an area and can't be a category` | `folderIsCategory = true` at the top level |
| `defaults.nix must be an attribute set, or a function of lib/inputs returning one` | a `defaults.nix` is anything else, such as a function asking for `config` |
| `expected an attribute set (a module) or a function` | a file evaluates to neither |
| `flake.modules has no type: add inputs.flake-parts.flakeModules.modules to imports, beside lib.tree` | the flake doesn't import `flake-parts.flakeModules.modules` |
| `a default.nix needs a folder to take its name from` | a `default.nix` sits directly in the tree's root |

dirs-as-categories checks `includes` and `enables` names whenever the flake
evaluates, not only when a host that uses those names does.

## Limits

- A flake can use only one `lib.tree`, because `lib.tree` declares the
  `flake.moduleGraph` option.
- You must import `flake-parts.flakeModules.modules`, because that module
  declares `flake.modules`. Without it, reading `flake.modules` stops with
  an error.
