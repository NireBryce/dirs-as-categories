# dirs-as-categories

> **Experimental. Don't use this unless you know what you're doing.**
> dirs-as-categories is young, and anything here can change without notice:
> the module file shape, which folders count as categories, the reserved
> keys, the error messages, and `flake.moduleGraph`'s format. If you use
> dirs-as-categories anyway, pin a revision in your `flake.lock`, read the
> changes before you update, and compare what your hosts build before and
> after; the
> [migration steps](wiki/using-the-flake.md#migrating-a-flake-that-names-its-modules-by-hand)
> show you how.

dirs-as-categories is an [import-tree](https://github.com/denful/import-tree)
preset for [flake-parts](https://github.com/hercules-ci/flake-parts) flakes.
It builds modules and categories from a folder tree.

You file modules in folders. dirs-as-categories names each module after its file,
turns folders that group modules into importable **categories**, and fills in
`flake.modules.<class>.<name>`. Hosts pick categories or modules by name.
You register nothing, and no file repeats its own name.

```
modules/
├─ hosts/
│  ├─ hosts.nix            a function: an ordinary flake-parts module
│  └─ laptop.nix           { includes.nixos = [ "base" "desktop" ]; nixos = { … }; }
└─ shared/
   ├─ base/                a category: it has a subfolder holding modules
   │  ├─ defaults.nix      applies whenever anything in base/ is used
   │  ├─ locale.nix        module `locale`
   │  └─ ssh/ssh.nix       module `ssh`
   └─ desktop/
      ├─ fonts/fonts.nix
      └─ kde/default.nix   module `kde` (default.nix takes its folder's name)
```

A host that includes `base` gets `locale`, `ssh` and base's `defaults.nix`;
a host that includes only `ssh` gets `ssh` and the same defaults.

## Quick start

Start a new flake from the template:

```sh
nix flake init -t github:NireBryce/dirs-as-categories
```

Or add dirs-as-categories to an existing flake-parts flake:

```nix
{
    inputs.dirs-as-categories = {
        url = "github:NireBryce/dirs-as-categories";
        inputs.import-tree.follows = "import-tree";   # if you have them
        inputs.flake-parts.follows = "flake-parts";
    };

    outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } {
        imports = [
            inputs.flake-parts.flakeModules.modules
            (inputs.dirs-as-categories.lib.tree ./modules)
            # more classes: (inputs.dirs-as-categories.lib.tree.addClasses [ "nixOnDroid" ] ./modules)
        ];
    };
}
```

## A module file

```nix
# shared/desktop/fonts/fonts.nix -> the module `fonts`, in two classes
{
    nixos       = { pkgs, ... }: { fonts.packages = [ pkgs.inter ]; };
    homeManager = { fonts.fontconfig.enable = true; };
}
```

| Key | Meaning |
|---|---|
| a class (`nixos`, `homeManager`, `darwin` by default) | that class's module |
| `includes.<class> = [ "name" … ]` | import these modules or categories by name |
| `enables.<class> = [ "name" … ]` | hand another class's module in as the argument `enabled.<class>.<name>` |
| `folderIsCategory = true \| false` | override whether this file's folder is a category |

To use the flake's `lib` or `inputs` in a module file, make the file a
function of `lib` and `inputs`:

```nix
{ lib, ... }:
{
    nixos = { services.openssh.enable = lib.mkDefault true; };
}
```

dirs-as-categories loads any other file -- a function that asks for
`config`, or a set with no class key such as `{ perSystem = …; }` -- as an
ordinary flake-parts module. Put `nixosConfigurations`, `perSystem` and
checks in files like these.

## The rules

- A module's name is its filename; `default.nix` takes its folder's name.
- A folder is a category when one of its subfolders holds modules, or when a
  file directly in the folder sets `folderIsCategory = true`. Setting
  `folderIsCategory = false` keeps a folder out. Top-level folders are areas
  and never categories.
- A category includes every module beneath it, at any depth.
- `defaults.nix` is never a module. A `defaults.nix`'s class parts apply
  whenever a configuration reaches anything in the file's folder's subtree,
  either through the nearest category at or above the folder or by
  including something inside the folder directly. Each `defaults.nix` loads
  once, however many routes reach the file.
- dirs-as-categories skips `_`-prefixed files and folders, as import-tree does.

On a mistake, dirs-as-categories stops evaluation, names the file, and
says how to fix it: two things with one name, an unknown key (`nixOS`,
with the key it resembles), a name in `includes` or `enables` that doesn't
exist in that class, `{ pkgs, ... }:` at the top of a file instead of
inside a class, a NixOS module such as `hardware-configuration.nix` in the
tree, files disagreeing on `folderIsCategory`.

For every rule and error, read [doc/convention.md](doc/convention.md). For
a walk-through with a worked example, migrating a flake, and what each
error means, read [wiki/using-the-flake.md](wiki/using-the-flake.md).

## What it publishes

`flake.moduleGraph` describes what dirs-as-categories built: categories,
folders, modules and their classes, includes, enables, defaults, the other
files, and any module nothing reaches (`orphans`). Setting
`dirsAsCategories.checkOrphans = true` makes `nix flake check` fail on an
orphan. [doc/format.md](doc/format.md) specifies the format, and
[flake-module-graph](https://github.com/NireBryce/flake-module-graph) draws
the graph.

```sh
nix eval --json .#moduleGraph
```

## Development

```sh
nix develop ./dev        # a shell with just, python3 and the linters
just preflight           # everything CI runs: flake check, error messages, doc checks, lint
just                     # every recipe
```

## Licence

dirs-as-categories is licensed under Apache-2.0. Copyright Nire Bryce.
