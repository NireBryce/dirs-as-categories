# Using the flake

_Last modified: 2026-10-17_

This page takes you from an empty flake to hosts with Home Manager, then
covers checks, migrating an existing flake, and what each error means. For
the exact rules, see [`../doc/convention.md`](../doc/convention.md).

**dirs-as-categories is experimental** and may change without notice; read
the [README](../README.md)'s notice before using dirs-as-categories on
anything you care about.

## Contents

- [Quick facts](#quick-facts)
- [Setting it up](#setting-it-up)
- [Laying out the tree](#laying-out-the-tree)
- [Writing a module](#writing-a-module)
- [A host](#a-host)
- [Home Manager, through `enables`](#home-manager-through-enables)
- [Settings for a whole folder: `defaults.nix`](#settings-for-a-whole-folder-defaultsnix)
- [Choosing which folders are categories](#choosing-which-folders-are-categories)
- [Files that are not modules](#files-that-are-not-modules)
- [Checking and drawing the tree](#checking-and-drawing-the-tree)
- [Migrating a flake that names its modules by hand](#migrating-a-flake-that-names-its-modules-by-hand)
- [When evaluation stops](#when-evaluation-stops)

## Quick facts

| You want to | Do |
|---|---|
| start a new flake | run `nix flake init -t github:NireBryce/dirs-as-categories`, or `…#home-manager` for Home Manager too |
| add a module | create a file `{ nixos = …; }` in a category's folder; the filename is the module's name |
| use `lib` or `inputs` in a module | make the file `{ lib, inputs, ... }: { nixos = …; }` |
| make a category | give a folder a subfolder holding modules (or set `folderIsCategory = true`) |
| give a host modules | add `includes.nixos = [ "category" "module" ];` to the host's file |
| hand a module of another class over | add `enables.homeManager = [ "name" ];`, then use `enabled.homeManager.name` |
| set defaults for a folder | put a `defaults.nix` with class keys in that folder |
| keep a NixOS module as it is (`hardware-configuration.nix`) | name it `_hardware.nix` and add `nixos.imports = [ ./_hardware.nix ];` |
| catch modules nothing uses | set `dirsAsCategories.checkOrphans = true;` |
| see what dirs-as-categories built | run `nix eval --json .#moduleGraph` |

## Setting it up

To start a new flake, run `nix flake init -t github:NireBryce/dirs-as-categories`.
The template has one host and one category, and a README listing the next
steps: naming the host, adding its hardware configuration, building it.
`nix flake init -t github:NireBryce/dirs-as-categories#home-manager` starts
from the tree this page uses instead.

To use an existing flake-parts flake, add the input and replace
`import-tree`'s line in `imports`:

```nix
{
    inputs = {
        nixpkgs.url     = "github:NixOS/nixpkgs/nixos-unstable";
        flake-parts.url = "github:hercules-ci/flake-parts";
        import-tree.url = "github:denful/import-tree";

        dirs-as-categories = {
            url = "github:NireBryce/dirs-as-categories/v0.1.1";   # a release tag: see CHANGELOG.md before moving it
            inputs = {
                import-tree.follows = "import-tree";
                flake-parts.follows = "flake-parts";
            };
        };
    };

    outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } {
        systems = [ "x86_64-linux" ];
        imports = [
            inputs.flake-parts.flakeModules.modules
            (inputs.dirs-as-categories.lib.tree ./modules)
        ];
    };
}
```

The `url` names a release tag, so `nix flake update` never moves you to a
release with breaking changes; to move, change the tag after reading the
[CHANGELOG](../CHANGELOG.md). `flake-parts.flakeModules.modules` declares
`flake.modules`, which dirs-as-categories fills. The `follows` lines keep one copy of import-tree
and flake-parts. For classes beyond `nixos`, `homeManager` and
`darwin`, use
`(inputs.dirs-as-categories.lib.tree.addClasses [ "nixOnDroid" ] ./modules)`.

## Laying out the tree

This page uses the tree below throughout. The tree is the `home-manager`
template ([`../templates/home-manager/`](../templates/home-manager/)):
`nix flake check` checks the template's tree, and on 2026-10-17 its host
evaluated to a toplevel derivation, with the user `me` getting git and
bash from Home Manager:

```
modules/
├─ hosts/
│  ├─ hosts.nix                     builds nixosConfigurations (not a module)
│  └─ laptop.nix                    the host: includes base, desktop
├─ users/
│  └─ me-home.nix                   the Home Manager config: includes shell
└─ shared/
   ├─ base/                         a category
   │  ├─ defaults.nix               applies whenever anything in base/ is used
   │  ├─ locale.nix
   │  ├─ ssh/ssh.nix
   │  └─ home-manager/enable-home-manager.nix
   ├─ shell/                        a category
   │  ├─ git/git.nix
   │  └─ bash/bash.nix
   └─ desktop/                      a category
      └─ plasma/plasma.nix
```

- **Top-level folders are areas** (`hosts`, `users`, `shared`). Areas only
  group files and are never categories.
- **A folder with a subfolder holding modules is a category**, named after
  the folder: `base`, `shell`, `desktop`. Including a category includes
  every module beneath the category, at any depth.
- **Other folders are plain folders** (`ssh/`, `git/`). Plain folders group
  files inside a category.
- **A file directly in an area is in no category.** Put hosts and home
  configurations there, so nothing includes them by accident.

## Writing a module

```nix
# shared/base/ssh/ssh.nix -- the module `ssh`
{
    nixos = {
        services.openssh.enable = true;
    };
}
```

The file doesn't name the module; dirs-as-categories takes the name from
the filename. Each key is a class, and a file can carry several:

```nix
# shared/shell/bash/bash.nix -- the module `bash`, in two classes
{
    nixos       = { programs.bash.completion.enable = true; };
    homeManager = { programs.bash.enable = true; };
}
```

A class's value is an ordinary module: an attribute set, or a function
taking `pkgs`, `config` and the rest from that class's evaluation. When the
file itself needs the flake's `lib` or `inputs`, make the file a function of
`lib` and `inputs`:

```nix
{ lib, ... }:
{
    nixos = {
        time.timeZone = lib.mkDefault "UTC";
    };
}
```

A `default.nix` takes its folder's name: `editors/micro/default.nix` is
the module `micro`. Modules and categories share one namespace, so two
things with one name stop evaluation (see [below](#when-evaluation-stops)).

## A host

```nix
# hosts/laptop.nix -- the module `laptop`
{
    includes.nixos = [ "base" "desktop" ];

    nixos = {
        networking.hostName  = "laptop";
        nixpkgs.hostPlatform = "x86_64-linux";
        system.stateVersion  = "26.05";
        boot.loader.grub.enable = false;
        fileSystems."/" = { device = "/dev/disk/by-label/nixos"; fsType = "ext4"; };
    };
}
```

`includes.nixos` lists categories or modules by name. Including `base`
brings in `locale`, `ssh`, `enable-home-manager` and `base`'s
`defaults.nix`. Then a plain flake-parts module builds the configuration:

```nix
# hosts/hosts.nix -- asks for `config`, so dirs-as-categories loads it as a flake-parts module
{ config, inputs, ... }:
{
    flake.nixosConfigurations.laptop = inputs.nixpkgs.lib.nixosSystem {
        modules = [ config.flake.modules.nixos.laptop ];
    };
}
```

For a darwin host, use `includes.darwin`, a `darwin` key, and
`darwinConfigurations`.

## Home Manager, through `enables`

A Home Manager configuration is a module with `includes` too:

```nix
# users/me-home.nix
{
    includes.homeManager = [ "shell" ];

    homeManager = {
        home.stateVersion = "26.05";
    };
}
```

A NixOS module hands `me-home` to Home Manager with `enables`, which
delivers the named module as the argument `enabled`:

```nix
# shared/base/home-manager/enable-home-manager.nix
{ inputs, ... }:
{
    enables.homeManager = [ "me-home" ];

    nixos = { enabled, ... }: {
        imports = [ inputs.home-manager.nixosModules.home-manager ];

        users.users.me.isNormalUser = true;
        home-manager.users.me = enabled.homeManager.me-home;
    };
}
```

`enabled` holds only the names you list in `enables`, so the declaration
can't drift from its use, and the published graph records the link. In the
example, the laptop's `home-manager.users.me` gets `shell`'s git and bash
settings.

## Settings for a whole folder: `defaults.nix`

```nix
# shared/base/defaults.nix
{ lib, ... }:
{
    nixos = {
        time.timeZone = lib.mkDefault "UTC";
    };
}
```

`defaults.nix` is never a module and has no name. A `defaults.nix`'s class
parts apply whenever a configuration reaches anything in the file's folder,
either through the category (here, `base`) or by including a module inside
the folder by name. The file loads once, however many routes reach it. Use
`mkDefault` so a host can override each setting.

## Choosing which folders are categories

By default, the subfolder rule decides. To choose yourself, put a
`defaults.nix` in the folder:

```nix
{ folderIsCategory = false; }   # keep a folder of folders plain
```

Set `folderIsCategory = true` to make a flat folder of files a category.
Promoting or demoting a folder changes which names exist, and promoting a
folder can change the order of list options such as package lists: the
same packages, a different hash. Compare your hosts before and after.

## Files that are not modules

A file is a module file when its keys are classes (or `includes`,
`enables`, `folderIsCategory`). dirs-as-categories loads any other file
unchanged, as an ordinary flake-parts module:

- a function asking for `config`, `withSystem` and the like (`hosts.nix`);
- a set with no class key: `{ perSystem = …; }`.

import-tree skips every path with a component starting with `_`. Put
helpers that other files `import` there.

### A NixOS module you want to keep as it is

`nixos-generate-config` writes `hardware-configuration.nix` as a NixOS
module: a function of `config`, `lib`, `pkgs` and `modulesPath`. A NixOS
module isn't a module file, so dirs-as-categories stops with an error if
you put one in the tree under its own name. Give the file a leading `_`,
so import-tree skips it, and import it from the host's class part:

```nix
# hosts/laptop.nix, beside hosts/_laptop-hardware.nix
{
    includes.nixos = [ "base" ];

    nixos = {
        imports = [ ./_laptop-hardware.nix ];
        networking.hostName = "laptop";
    };
}
```

## Checking and drawing the tree

- **Orphans** are modules inside a category that nothing includes or
  enables. Orphans evaluate fine and install nothing. To catch them, turn
  on the check:

  ```nix
  # in any flake-parts module, for example hosts.nix
  dirsAsCategories.checkOrphans = true;
  ```

  `nix flake check` then fails and names each orphan and its path.
- **What dirs-as-categories built**: run `nix eval --json .#moduleGraph` to
  print the categories, modules and their classes, includes, enables,
  defaults and orphans ([format](../doc/format.md)).
- **A picture**:
  [flake-module-graph](https://github.com/NireBryce/flake-module-graph)
  draws the graph: `nix run github:NireBryce/flake-module-graph -- html --flake . > modules.html`.

## Migrating a flake that names its modules by hand

If each file in your flake writes `flake.modules.<class>.<name> = …`,
convert the flake one file at a time:

1. **Record what each host builds**, before changing anything:
   `nix eval --raw .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath`
   for each host, and the same for Home Manager generations.
2. **Unwrap each module**: change `flake.modules.nixos.<name> = X;` to
   `nixos = X;`, and delete any binding that derives the name from the
   filename (`__curPos.file`). If the name differed from the filename,
   rename the file. Keep `{ lib, ... }:` only if the body uses `lib`.
3. **Turn hosts' import lists into `includes`**: replace
   `imports = with config.flake.modules.nixos; [ base desktop ];` with
   `includes.nixos = [ "base" "desktop" ];`, and make `hosts.nix` refer to
   the host by its new name.
4. **Replace references to other modules**: turn
   `config.flake.modules.<class>.<name>` inside a module into `includes`
   (same class) or `enables` (another class), and read the flake's own
   outputs through `inputs.self.…`.
5. **Compare** every drvPath with the drvPaths from step 1. A difference
   with identical contents usually comes from list order: check whether a
   folder became a category, and pin that folder with `folderIsCategory`.

## When evaluation stops

Each message starts `error: dirs-as-categories:`, followed by the file or
folder and what is wrong.

| Message | Fix |
|---|---|
| `names used more than once: x (a/one/x.nix, a/two/x.nix)` | rename one of the files; modules and categories share one namespace, and `x/default.nix` beside `x.nix` counts as a clash too |
| `` <file>: unknown key `nixOS`; expected one of: … `` | correct the typo in the class or reserved key |
| `` <file>: includes.nixos: unknown name `nope` `` | no module or category has that name |
| `` <file>: includes.nixos: unknown name `one` (a/c/one is a plain folder, which has no name; …) `` | you can't include a plain folder: include the folder's category, or make the folder a category |
| `` <file>: includes.nixos: `x` has no nixos module `` | the name exists, but not in that class |
| `<file>: includes.nixOS: unknown class` | correct the class after `includes.` |
| `` <file>: enables.homeManager: unknown name `ghost` `` | as for `includes` |
| `<folder>: files disagree on folderIsCategory` | two files in one folder set different values; make the values agree |
| `<folder>: folderIsCategory must be true or false` | set `folderIsCategory` to `true` or `false` |
| `a: a top-level folder is an area and can't be a category` | remove `folderIsCategory = true` from the area |
| `` <file>: unknown key `nixOS` (did you mean `nixos`?) `` | the file's only class key is mistyped; correct it |
| `` <file>: asks for `pkgs` at the top of the file, where only `lib` and `inputs` exist; move it into the class: … `` | move `{ pkgs, ... }:` from the top of the file into the class, as the message shows; the top of a module file may ask only for `lib` and `inputs` |
| `` <file>: asks for `modulesPath`, `pkgs`, which only a NixOS or Home Manager module gets; … `` | the file is a NixOS module; [keep it as it is](#a-nixos-module-you-want-to-keep-as-it-is) |
| `` <file>: includes.nixos: unknown name `lcoale` (did you mean `locale`?) `` | correct the name |
| `<file>: defaults.nix must be an attribute set, or a function of lib/inputs returning one` | the `defaults.nix` asks for `config`; only a class part may ask for `config`, as in `nixos = { config, ... }: …` |
| `<file>: expected an attribute set (a module) or a function (a module of lib/inputs, or a flake-parts module)` | the file evaluates to something else, such as a list or a string; make the file a set of class keys |
| `flake.modules has no type: add inputs.flake-parts.flakeModules.modules to imports, beside lib.tree` | add `inputs.flake-parts.flakeModules.modules` to the flake's `imports`, as in [Setting it up](#setting-it-up) |
| `default.nix: a default.nix needs a folder to take its name from` | a `default.nix` in the tree's root has no folder to name it; move the file into a folder, or rename it |

An import-tree older than 2026-07-16 stops with
`You need to call withLib before trying to read the tree.` before
dirs-as-categories reads anything: update import-tree
(`nix flake update import-tree`). The [README](../README.md#requirements)
lists the oldest versions dirs-as-categories works with.

A mistake outside the files dirs-as-categories reads -- in a class part's
own settings, say -- stops with an error from NixOS, Home Manager or
flake-parts instead. Read such an error to the bottom: Nix prints the
innermost cause last.
