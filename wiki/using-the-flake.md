# Using the flake

_Last modified: 2026-10-23_

This page shows how dirs-as-categories works on an example flake, how to
add it to your flake, and how to lay out a tree with hosts and Home
Manager. It also covers checks, migrating a flake that names its modules by
hand, and what each error means. For the exact rules, see
[`../doc/convention.md`](../doc/convention.md).

**dirs-as-categories is experimental** and may change without notice; read
the [README](../README.md)'s notice before using dirs-as-categories on
anything you care about.

## Contents

- [Quick facts](#quick-facts)
- [How it works, on the example flake](#how-it-works-on-the-example-flake)
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
| use it in your flake | add the input, and `(inputs.dirs-as-categories.lib.tree ./modules)` to `imports` ([Setting it up](#setting-it-up)) |
| see it work on an example | read [How it works, on the example flake](#how-it-works-on-the-example-flake) |
| add a module | create a file `{ nixos = …; }` in a category's folder; the filename is the module's name |
| use `lib` or `inputs` in a module | make the file `{ lib, inputs, ... }: { nixos = …; }` |
| make a category | give a folder a subfolder holding modules (or set `folderIsCategory = true`) |
| give a host modules | add `includes.nixos = [ "category" "module" ];` to the host's file |
| hand a module of another class over | add `enables.homeManager = [ "name" ];`, then use `enabled.homeManager.name` |
| set defaults for a folder | put a `defaults.nix` with class keys in that folder |
| keep a NixOS module as it is (`hardware-configuration.nix`) | name it `_hardware.nix` and add `nixos.imports = [ ./_hardware.nix ];` |
| catch modules nothing uses | set `dirsAsCategories.checkOrphans = true;` |
| see what dirs-as-categories built | run `nix eval --json .#moduleGraph` |

## How it works, on the example flake

[`example-flake/home-manager/`](../example-flake/home-manager/) is a small
flake that uses dirs-as-categories: a NixOS host, `laptop`, whose user
`me` gets a Home Manager configuration. It is an example to read and
evaluate, not a configuration to switch a machine to. From a clone of
this repository, ask what dirs-as-categories built from it:

```sh
nix eval --json --no-write-lock-file ./example-flake/home-manager#moduleGraph
```

Its `flake.nix` has the two lines from [Setting it up](#setting-it-up):
the input, and `(inputs.dirs-as-categories.lib.tree ./modules)` in
`imports`. Everything else comes from the files under `modules/` (the
tree is drawn in [Laying out the tree](#laying-out-the-tree)):

1. **Each file is a module, named after the file.**
   `shared/base/ssh/ssh.nix` holds `{ nixos = …; }`, so it becomes
   `flake.modules.nixos.ssh`; the graph lists it as `modules.ssh`, with
   `classes` `[ "nixos" ]`.
2. **Folders become categories.** `shared/base/` has subfolders that hold
   modules, so it is the category `base`, and `categories.base.members`
   is `[ "enable-home-manager" "locale" "ssh" ]`. `ssh/` is a plain
   folder (listed in `folders`): it only groups files. `shared/` is at the
   top level, an area, and never a category.
3. **A host includes things by name.** `hosts/laptop.nix` sets
   `includes.nixos = [ "base" "desktop" ];`, which the graph shows as
   `includes.laptop`. Including `base` brings every module beneath it,
   and `shared/base/defaults.nix` with them (listed in `defaults`).
4. **A module can hand one of another class over.**
   `enable-home-manager.nix` sets `enables.homeManager = [ "me-home" ];`
   and gives `enabled.homeManager.me-home` to Home Manager as the user
   `me`'s configuration. `users/me-home.nix` includes the category
   `shell`, so `me` gets git and bash.
5. **Any other file is ordinary flake-parts.** `hosts/hosts.nix` asks for
   `config`, so it is not a module file: dirs-as-categories imports it as
   it is (listed in `admin`), and it builds
   `nixosConfigurations.laptop` from `flake.modules.nixos.laptop`.
6. **Draw it** with
   [flake-module-graph](https://github.com/NireBryce/flake-module-graph):

   ```sh
   nix run github:NireBryce/flake-module-graph/v0.1.0 -- html --flake ./example-flake/home-manager > modules.html
   ```

Each step has its own section below. A file added to the tree shows up
the same way: `shared/shell/fish/fish.nix` holding
`{ homeManager.programs.fish.enable = true; }` joins `shell`'s members,
and `me` gets it with no other change.
[`example-flake/default/`](../example-flake/default/) is a smaller
example: one host and one category.

## Setting it up

These steps add dirs-as-categories to a flake-parts flake you already
have.

1. **Add the input**, beside flake-parts and import-tree:

   ```nix
   {
       inputs = {
           nixpkgs.url     = "github:NixOS/nixpkgs/nixos-unstable";
           flake-parts.url = "github:hercules-ci/flake-parts";
           import-tree.url = "github:denful/import-tree";

           dirs-as-categories = {
               url = "github:NireBryce/dirs-as-categories/v0.2.0";   # a release tag: see CHANGELOG.md before moving it
               inputs = {
                   import-tree.follows = "import-tree";
                   flake-parts.follows = "flake-parts";
               };
           };
       };
   }
   ```

   The `url` names a release tag, so `nix flake update` never moves you to
   a release with breaking changes; to move, change the tag after reading
   the [CHANGELOG](../CHANGELOG.md). The `follows` lines keep one copy of
   import-tree and flake-parts.
2. **Import the tree** in `mkFlake`'s `imports`, in place of import-tree's
   line if you have one:

   ```nix
   {
       outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } {
           systems = [ "x86_64-linux" ];
           imports = [
               inputs.flake-parts.flakeModules.modules
               (inputs.dirs-as-categories.lib.tree ./modules)
           ];
       };
   }
   ```

   `flake-parts.flakeModules.modules` declares `flake.modules`, which
   dirs-as-categories fills. For classes beyond `nixos`, `homeManager` and
   `darwin`, use
   `(inputs.dirs-as-categories.lib.tree.addClasses [ "nixOnDroid" ] ./modules)`.
   A flake that doesn't use flake-parts yet needs its outputs inside
   `mkFlake` first.
3. **Put your modules under `modules/`**, one file per module, named after
   it ([Laying out the tree](#laying-out-the-tree),
   [Writing a module](#writing-a-module)). Files that already set
   `flake.modules.<class>.<name>` themselves convert one at a time
   ([Migrating](#migrating-a-flake-that-names-its-modules-by-hand)).
4. **Build each host from `flake.modules`**, in a file that asks for
   `config` ([A host](#a-host)):
   `nixosConfigurations.laptop = inputs.nixpkgs.lib.nixosSystem { modules = [ config.flake.modules.nixos.laptop ]; };`.
5. **Look before you switch**: `nix eval --json .#moduleGraph` shows what
   each host includes, and `nixos-rebuild build --flake .#laptop` builds
   the host without activating it.

## Laying out the tree

This page uses the tree below throughout. The tree is the example
flake's ([`../example-flake/home-manager/`](../example-flake/home-manager/)):
`nix flake check` checks the example's tree, and on 2026-10-17 its host
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

`enabled` holds only the names you list in `enables`, so a module can use
only what it declares, and the published graph records the link. In the
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
packages stay the same but the hash changes. Compare your hosts before
and after.

## Files that are not modules

A file is a module file when its keys are classes (or `includes`,
`enables`, `folderIsCategory`). dirs-as-categories loads any other file
unchanged, as an ordinary flake-parts module:

- a function asking for `config`, `withSystem` and the like (`hosts.nix`);
- a set with no class key: `{ perSystem = …; }`.

import-tree skips every path with a component starting with `_`. Put
helpers that other files `import` there.

`_` hides a file from dirs-as-categories, not from the Nix store. Every
file git tracks in a flake is copied to `/nix/store`, which every user on
the machine can read, whether anything imports it or not. Keep passwords,
keys and tokens out of the tree: use a secrets tool such as sops-nix or
agenix, or an option that reads a file at run time, such as
`users.users.<name>.hashedPasswordFile`.

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
  draws the graph: `nix run github:NireBryce/flake-module-graph/v0.1.0 -- html --flake . > modules.html`.

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
| `` a/outPath.nix: `outPath` can't be a name: … `` | rename the file or folder; Nix gives `outPath` a meaning of its own |
| `` <file>: unknown key `nixOS` (did you mean `nixos`?); expected one of: … `` | correct the typo in the class or reserved key |
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
| `flake.moduleGraph describes one modules tree, and this flake imports 2: …` | the flake imports two trees, and a tool such as flake-module-graph read the graph; the graph format covers one tree, so import one tree when you want the graph |

An import-tree older than 2026-07-16 stops with
`You need to call withLib before trying to read the tree.` before
dirs-as-categories reads anything: update import-tree
(`nix flake update import-tree`). The [README](../README.md#requirements)
lists the oldest versions dirs-as-categories works with.

A mistake outside the files dirs-as-categories reads -- in a class part's
own settings, say -- stops with an error from NixOS, Home Manager or
flake-parts instead. Read such an error to the bottom: Nix prints the
innermost cause last.
