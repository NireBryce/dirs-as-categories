# dirs-as-categories

Modules and categories from a folder tree, for
[flake-parts](https://github.com/hercules-ci/flake-parts) flakes. An
[import-tree](https://github.com/denful/import-tree) preset.

You file modules in folders. dirs-as-categories names each module after its file,
makes folders that group modules into importable **categories**, and fills in
`flake.modules.<class>.<name>`. Hosts pick categories or modules by name.
There is nothing to register and no name to repeat inside a file.

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

Including `base` gives a host `locale`, `ssh` and base's `defaults.nix`;
including `ssh` alone gives it `ssh` and the same defaults.

## Quick start

```sh
nix flake init -t github:NireBryce/dirs-as-categories
```

or add it to an existing flake-parts flake:

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
            # other classes: (inputs.dirs-as-categories.lib.tree.withClasses [ "nixos" "homeManager" "darwin" "nixOnDroid" ] ./modules)
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

A module file may also be a function of the flake's `lib` and `inputs`, so
its body can use them:

```nix
{ lib, ... }:
{
    nixos = { services.openssh.enable = lib.mkDefault true; };
}
```

Any other file -- a function asking for `config`, or anything with no class
key, such as `{ perSystem = …; }` -- is loaded as an ordinary flake-parts
module, for anything that isn't a module of a class: `nixosConfigurations`,
`perSystem`, checks.

## The rules

- A module's name is its filename; `default.nix` takes its folder's name.
- A folder is a category when one of its subfolders holds modules, or when a
  file directly in it sets `folderIsCategory = true`. `false` opts a folder
  out. Top-level folders are areas and never categories.
- A category includes every module beneath it, at any depth.
- `defaults.nix` is never a module. Its class parts apply whenever anything
  in its folder's subtree is reached: through the nearest category at or above
  the folder, or through a direct include of anything inside it. It loads once
  however many routes reach it.
- `_`-prefixed files and folders are skipped, as in import-tree.

Mistakes stop evaluation with a message naming the file: two things with one
name, an unknown key (`nixOS`), a name in `includes` or `enables` that doesn't
exist in that class, files disagreeing on `folderIsCategory`.

[doc/convention.md](doc/convention.md) states every rule and error.

## What it publishes

`flake.moduleGraph` describes what was built: categories, folders, modules
and their classes, includes, enables, defaults, the other files, and any
module nothing reaches (`orphans`; `dirsAsCategories.checkOrphans = true`
makes `nix flake check` fail on one).
[doc/format.md](doc/format.md) is the format;
[flake-module-graph](https://github.com/NireBryce/flake-module-graph) draws it.

```sh
nix eval --json .#moduleGraph
```

## Development

```sh
nix flake check          # fixture trees, error fixtures, the template
python3 tests/errors.py  # each error fixture's message
```

## Licence

Apache-2.0. Copyright Nire Bryce.
