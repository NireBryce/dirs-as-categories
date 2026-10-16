# The convention

Every rule dirs-as-categories applies, and every error it raises. Paths are
relative to the folder passed to `lib.tree`.

All of it is decided from file paths and from the shape of what each file
evaluates to, never from `config`. That is what lets it build `imports` and
`flake.modules` names without recursing through the module system.

## Files

import-tree finds the files: every `.nix` file, except paths with a component
starting with `_`.

| A file that evaluates to | is |
|---|---|
| an attribute set, named `defaults.nix` | a [defaults file](#defaultsnix) |
| any other attribute set | a [module file](#module-files) |
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

dirs-as-categories calls such a function to see what it returns. That is
safe because both arguments exist before `config` does (`inputs` is a
flake-parts special argument, `lib` is always given), so reading the result's
keys can't recurse through the module system. The function's required
arguments decide:

- only `lib` and/or `inputs` (anything else must have a default): called with
  just those. If the result has a class or reserved key it is a module file
  (or, for `defaults.nix`, a defaults file); otherwise it is a flake-parts
  module, imported as written -- `{ lib, ... }: { perSystem = …; }` stays one.
- anything else, such as `config` or `withSystem`: never called; a
  flake-parts module.

One consequence: a function-form file whose only class key is mistyped
(`{ lib, ... }: { nixOS = …; }`) has no class key, so it is loaded as a
flake-parts module, and flake-parts rejects the unknown option `nixOS`. A
plain attribute set with the same typo is caught by dirs-as-categories
itself, naming the file.

## Module files

Allowed keys:

| Key | Value |
|---|---|
| a class | that class's module: an attribute set, a function, or a path |
| `includes` | `{ <class> = [ name … ]; }` |
| `enables` | `{ <class> = [ name … ]; }` |
| `folderIsCategory` | `true` or `false` |

The classes are `nixos`, `homeManager` and `darwin`, or the list given to
`lib.tree.withClasses`.

A module file declares the module `<name>` in every class it has a key for,
and in every class it has `includes` for. A file with neither (only
`folderIsCategory`) declares nothing.

**Name.** The filename without `.nix`. A file named `default.nix` takes its
folder's name instead. A `default.nix` directly in the tree's root is an
error.

**`includes.<class>`.** Each name is a module or category of that class; the
module imports them. Every module and category is one namespace, so a name
means one thing.

**`enables.<class>`.** Each name is a module or category of that class. The
module file's own class modules that are functions receive the argument
`enabled.<class>.<name>`, the named module, alongside their usual arguments:

```nix
{
    enables.homeManager = [ "my-home" ];
    nixos = { enabled, ... }: {
        home-manager.users.me = enabled.homeManager.my-home;
    };
}
```

Only what is declared is in `enabled`, so the declaration can't drift from
the use. `flake.moduleGraph` records the link.

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
`lib` and/or `inputs` returning one. Allowed keys: the classes, and
`folderIsCategory` (which applies to its folder as in any other file).

Its class parts apply whenever anything in its folder's subtree is reached:

- through the nearest category at or above its folder (so a `defaults.nix` in
  a plain folder moves up to the category that holds it), or
- through a direct include of any module or category inside its folder.

Each loads once per configuration however many routes reach it: every module
dirs-as-categories creates carries a `key`.

Definitions keep their file: errors and `options.<x>.definitionsWithLocations`
name `defaults.nix`, not dirs-as-categories.

## Errors

Each stops evaluation with `dirs-as-categories: <path>: <what>`.

| Error | Raised when |
|---|---|
| `names used more than once: <name> (<paths>)` | two modules, two categories, or a module and a category share a name (including `x.nix` beside `x/default.nix`) |
| `unknown key` | a module file or `defaults.nix` has a key that isn't allowed |
| `<kind>.<class>: unknown class` | `includes` or `enables` names a class not in the list |
| `<kind>.<class>: unknown name` | a name in `includes`/`enables` isn't a module or category |
| `<kind>.<class>: <name> has no <class> module` | the name exists, but not in that class |
| `files disagree on folderIsCategory` | two files in one folder set different values |
| `folderIsCategory must be true or false` | it is set to something else |
| `a top-level folder is an area and can't be a category` | `folderIsCategory = true` at the top level |
| `defaults.nix must be an attribute set, or a function of lib/inputs returning one` | a `defaults.nix` is anything else, such as a function asking for `config` |
| `expected an attribute set (a module) or a function` | a file evaluates to neither |

`includes` and `enables` names are checked when the flake is evaluated, not
only when a host that uses them is.

## Limits

- One `lib.tree` per flake: it declares the `flake.moduleGraph` option.
- `flake-parts.flakeModules.modules` must be imported; it declares
  `flake.modules`.
