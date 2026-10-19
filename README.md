# dirs-as-categories

> **Experimental. Don't use this unless you know what you're doing.**
> dirs-as-categories is young, and anything here can change without notice:
> the module file shape, which folders count as categories, the reserved
> keys, the error messages, and `flake.moduleGraph`'s format. If you use
> dirs-as-categories anyway, pin a release tag (`github:NireBryce/dirs-as-categories/v0.2.0`),
> read the [CHANGELOG](CHANGELOG.md) before you move to a newer one, and compare what your hosts build before and
> after; the
> [migration steps](wiki/using-the-flake.md#migrating-a-flake-that-names-its-modules-by-hand)
> show you how.

dirs-as-categories is an [import-tree](https://github.com/denful/import-tree)
preset for [flake-parts](https://github.com/hercules-ci/flake-parts) flakes.
It builds modules and categories from a folder tree.

New to flakes or flake-parts? [Words this project uses](wiki/concepts.md)
defines each term below.

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

Add dirs-as-categories to your flake-parts flake
([Using the flake](wiki/using-the-flake.md#setting-it-up) walks through
it):

```nix
{
    inputs.dirs-as-categories = {
        url = "github:NireBryce/dirs-as-categories/v0.2.0";   # a release tag: see CHANGELOG.md before moving it
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

To see how it works first,
[How it works, on the example flake](wiki/using-the-flake.md#how-it-works-on-the-example-flake)
walks through [`example-flake/`](example-flake/), a flake in this
repository to read and evaluate.

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

[CONTRIBUTING.md](CONTRIBUTING.md) is where to start;
[Changing dirs-as-categories](wiki/changing-dirs-as-categories.md) walks
through the checks and the test-first loop.

```sh
nix develop ./dev        # a shell with just, python3 and the linters
just preflight           # everything CI runs: flake check, error messages, doc checks, lint
just                     # every recipe
```

## Requirements

| Needs | Oldest tested |
|---|---|
| Nix, with flakes | 2.18 |
| flake-parts | `d50b490` (2024-09-12), which added `flakeModules.modules`; its nixpkgs `lib` is 24.11.20240901 |
| import-tree | `4ebb10a` (2026-07-16), which stopped needing `withLib` |

CI runs every fixture and error message against these, in the `oldest`
job of [`.github/workflows/check.yml`](.github/workflows/check.yml), and
against the newest flake-parts and import-tree every week. Your flake's
`follows` decide which versions dirs-as-categories gets. An older
import-tree stops with `You need to call withLib before trying to read the
tree.`: update import-tree.

## Licence

dirs-as-categories is licensed under Apache-2.0. Copyright Nire Bryce.
