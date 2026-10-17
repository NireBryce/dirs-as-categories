# The convention

Every rule dirs-as-categories applies, and every error it raises. These
rules are **experimental** and may change (see the [README](../README.md)). Paths are
relative to the folder you pass to `lib.tree`.

dirs-as-categories decides everything from file paths and from the shape of
what each file evaluates to, never from `config`. Because of this, it can
build `imports` and `flake.modules` names without recursing through the
module system.

## Files

import-tree finds the files: every `.nix` file, except paths with a component
starting with `_`.

| A file that evaluates to | is |
|---|---|
| an attribute set, named `defaults.nix` | a [defaults file](#defaultsnix) |
| any other attribute set with a class or reserved key | a [module file](#module-files) |
| an attribute set with neither (`{ perSystem = …; }`) | a flake-parts module, imported as it is |
| a function of only `lib` and/or `inputs` that returns a class or reserved key | a module file (or defaults file), called with those |
| any other function | a flake-parts module, imported as it is |
| anything else | an error |

### Functions of `lib` and `inputs`

A module file can take the flake's `lib` and `inputs`, so its body can use
them the way a flake-parts module's would:

```nix
{ lib, inputs, ... }:
{
    nixos = {
        imports = [ inputs.some-flake.nixosModules.default ];
        services.foo.enable = lib.mkDefault true;
    };
}
```

dirs-as-categories calls such a function to see what it returns. This is
safe: both arguments exist before `config` does (`inputs` is a flake-parts
special argument, and flake-parts always passes `lib`), so reading the
result's keys can't recurse through the module system. dirs-as-categories
looks at the function's required arguments:

- only `lib` and/or `inputs` (anything else must have a default): it calls
  the function with just those. If the result has a class or reserved key,
  the file is a module file (or, for `defaults.nix`, a defaults file);
  otherwise dirs-as-categories imports it unchanged as a flake-parts module,
  so `{ lib, ... }: { perSystem = …; }` stays one.
- anything else, such as `config` or `withSystem`: it never calls the
  function and imports it as a flake-parts module.

This has one consequence for both forms. If you mistype a file's only class
key (`{ nixOS = …; }`), the file has no class key, so dirs-as-categories
loads it as a flake-parts module and flake-parts rejects the unknown option
`nixOS`. If you mistype a key beside a real one
(`{ nixos = …; nixOS = …; }`), dirs-as-categories catches it and names the
file.

## Module files

A module file may use these keys:

| Key | Value |
|---|---|
| a class | that class's module: an attribute set, a function, or a path |
| `includes` | `{ <class> = [ name … ]; }` |
| `enables` | `{ <class> = [ name … ]; }` |
| `folderIsCategory` | `true` or `false` |

The classes are `nixos`, `homeManager` and `darwin`, or the list you give
`lib.tree.withClasses`.

A module file declares the module `<name>` in every class it has a key for,
and in every class it has `includes` for. A file with neither (only
`folderIsCategory`) declares nothing.

**Name.** The filename without `.nix`. A file named `default.nix` takes its
folder's name instead. A `default.nix` directly in the tree's root is an
error.

**`includes.<class>`.** Each name is a module or category of that class; the
module imports them. Modules and categories share one namespace, so a name
means one thing.

**`enables.<class>`.** Each name is a module or category of that class.
dirs-as-categories passes each named module to this file's class modules as
the argument `enabled.<class>.<name>`, alongside their usual arguments; a
class module must be a function to receive it:

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

1. a file directly in it (a module file or its `defaults.nix`) sets
   `folderIsCategory`: that value decides; otherwise
2. one of its subfolders, at any depth, holds a module file declaring a module.

Top-level folders are **areas**. They are never categories; setting
`folderIsCategory = true` in one is an error.

A category is a module named after its folder, in every class. It imports:

- the modules beneath it that belong to no nested category,
- the categories nested in it that are nested in no other category under it,
- its `defaults.nix` reach (below).

So including a category includes everything beneath it.

A folder that isn't a category is a **plain folder**: it has no name, and its
modules belong to the nearest category above it.

## defaults.nix

A `defaults.nix` is never a module. It is an attribute set, or a function of
`lib` and/or `inputs` returning one. It may use the class keys and
`folderIsCategory`, which applies to its folder as in any other file.

Its class parts apply whenever a configuration reaches anything in its
folder's subtree:

- through the nearest category at or above its folder (so a `defaults.nix` in
  a plain folder moves up to the category that holds it), or
- by including any module or category inside its folder directly.

Each one loads once per configuration, however many routes reach it,
because every module dirs-as-categories creates carries a `key`.

Definitions keep their file: errors and `options.<x>.definitionsWithLocations`
name `defaults.nix`, not dirs-as-categories.

## Orphans

If no `includes` or `enables` reaches a module inside a category, the
module still evaluates but installs nothing, so evaluation can't report it.
An `includes` or `enables` reaches a module by naming it or a category above
it (a category includes everything beneath it). Modules outside every
category are entry points (hosts, home aggregates); nothing is meant to name
them, so they are never orphans.

`flake.moduleGraph.orphans` lists them. With

```nix
dirsAsCategories.checkOrphans = true;
```

`nix flake check` also runs `checks.<system>.module-orphans`, which fails
and names each orphan and its path. It is off by default because it adds a
check to your flake.

## Errors

Each error stops evaluation with `dirs-as-categories: <path>: <what>`.

| Error | Raised when |
|---|---|
| `names used more than once: <name> (<paths>)` | two modules, two categories, or a module and a category share a name (including `x.nix` beside `x/default.nix`) |
| `unknown key` | a module file or `defaults.nix` has a key that isn't allowed |
| `<kind>.<class>: unknown class` | `includes` or `enables` names a class not in the list |
| `<kind>.<class>: unknown name` | a name in `includes`/`enables` isn't a module or category |
| `<kind>.<class>: <name> has no <class> module` | the name exists, but not in that class |
| `files disagree on folderIsCategory` | two files in one folder set different values |
| `folderIsCategory must be true or false` | it has any other value |
| `a top-level folder is an area and can't be a category` | `folderIsCategory = true` at the top level |
| `defaults.nix must be an attribute set, or a function of lib/inputs returning one` | a `defaults.nix` is anything else, such as a function asking for `config` |
| `expected an attribute set (a module) or a function` | a file evaluates to neither |

dirs-as-categories checks `includes` and `enables` names whenever the flake
evaluates, not only when a host that uses them does.

## Limits

- One `lib.tree` per flake: it declares the `flake.moduleGraph` option.
- You must import `flake-parts.flakeModules.modules`; it declares
  `flake.modules`.
