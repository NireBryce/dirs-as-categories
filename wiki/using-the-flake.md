# Using the flake

_Last modified: 2026-10-16_

A walk-through of dirs-as-categories from an empty flake to hosts with Home
Manager, then checks, migrating an existing flake, and what each error
means. For the exact rules, see [`../doc/convention.md`](../doc/convention.md).

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
| start a new flake | `nix flake init -t github:NireBryce/dirs-as-categories` |
| add a module | a file `{ nixos = …; }` in a category's folder; its name is its filename |
| use `lib` or `inputs` in it | make the file `{ lib, inputs, ... }: { nixos = …; }` |
| make a category | a folder with a subfolder holding modules (or `folderIsCategory = true`) |
| give a host modules | `includes.nixos = [ "category" "module" ];` in the host's file |
| hand a module of another class over | `enables.homeManager = [ "name" ];`, then `enabled.homeManager.name` |
| set defaults for a folder | `defaults.nix` with class keys, in that folder |
| catch modules nothing uses | `dirsAsCategories.checkOrphans = true;` |
| see what was built | `nix eval --json .#moduleGraph` |

## Setting it up

New flake: `nix flake init -t github:NireBryce/dirs-as-categories` writes a
flake with one host and one category.

Existing flake-parts flake: add the input and replace `import-tree`'s line
in `imports`:

```nix
{
    inputs = {
        nixpkgs.url     = "github:NixOS/nixpkgs/nixos-unstable";
        flake-parts.url = "github:hercules-ci/flake-parts";
        import-tree.url = "github:denful/import-tree";

        dirs-as-categories = {
            url = "github:NireBryce/dirs-as-categories";
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

`flake-parts.flakeModules.modules` declares `flake.modules`, which this
fills. The `follows` lines keep one copy of import-tree and flake-parts.
Other classes than `nixos`, `homeManager` and `darwin`:
`(inputs.dirs-as-categories.lib.tree.withClasses [ "nixos" "nixOnDroid" ] ./modules)`.

## Laying out the tree

The example used through this page -- built as a flake and evaluated to a
toplevel derivation before this page was written:

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

- **Top-level folders are areas** (`hosts`, `users`, `shared`): grouping
  only, never categories.
- **A folder with a subfolder holding modules is a category**, named after
  the folder: `base`, `shell`, `desktop`. Including it includes every module
  beneath it, at any depth.
- **Other folders are plain folders** (`ssh/`, `git/`): grouping inside a
  category.
- **A file directly in an area is in no category** -- the place for hosts
  and home configurations, which nothing should include by accident.

## Writing a module

```nix
# shared/base/ssh/ssh.nix -- the module `ssh`
{
    nixos = {
        services.openssh.enable = true;
    };
}
```

The file names no module: its name is its filename, and each key is a
class. A file can carry several:

```nix
# shared/shell/bash/bash.nix -- the module `bash`, in two classes
{
    nixos       = { programs.bash.completion.enable = true; };
    homeManager = { programs.bash.enable = true; };
}
```

A class's value is an ordinary module -- an attribute set, or a function
taking `pkgs`, `config` and the rest from that class's evaluation. When the
file itself needs the flake's `lib` or `inputs`, make it a function of
those two:

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

`includes.nixos` names categories or modules; including `base` brings
`locale`, `ssh`, `enable-home-manager` and `base`'s `defaults.nix`. Then a
plain flake-parts module builds the configuration:

```nix
# hosts/hosts.nix -- asks for `config`, so it is loaded as a flake-parts module
{ config, inputs, ... }:
{
    flake.nixosConfigurations.laptop = inputs.nixpkgs.lib.nixosSystem {
        modules = [ config.flake.modules.nixos.laptop ];
    };
}
```

A darwin host is the same with `includes.darwin`, a `darwin` key, and
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

A NixOS module hands it to Home Manager with `enables`, which delivers the
named module as the argument `enabled`:

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

Only names listed in `enables` are in `enabled`, so the declaration can't
drift from its use, and the published graph records the link. In the
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

`defaults.nix` is never a module and has no name. Its class parts apply
whenever anything in its folder is reached: through the category (here,
`base`) or through a module inside it included by name. It loads once
however many routes reach it. Use `mkDefault` so a host can override it.

## Choosing which folders are categories

The subfolder rule decides by default. To decide yourself, put a
`defaults.nix` in the folder:

```nix
{ folderIsCategory = false; }   # keep a folder of folders plain
```

`true` makes a flat folder of files a category. Promoting or demoting a
folder changes which names exist, and promoting one can change the order
of list options such as package lists -- the same packages, a different
hash. Compare your hosts before and after.

## Files that are not modules

A file is a module file when its keys are classes (or `includes`,
`enables`, `folderIsCategory`). Anything else is an ordinary flake-parts
module, loaded as written:

- a function asking for `config`, `withSystem` and the like (`hosts.nix`);
- a set with no class key: `{ perSystem = …; }`.

Paths with a component starting with `_` are skipped entirely -- the place
for helpers other files `import`.

## Checking and drawing the tree

- **Orphans** -- modules inside a category that nothing includes or
  enables -- evaluate fine and install nothing. Turn on the check:

  ```nix
  # in any flake-parts module, for example hosts.nix
  dirsAsCategories.checkOrphans = true;
  ```

  `nix flake check` then fails naming each one and its path.
- **What was built**: `nix eval --json .#moduleGraph` -- categories,
  modules and their classes, includes, enables, defaults, orphans
  ([format](../doc/format.md)).
- **A picture**:
  [flake-module-graph](https://github.com/NireBryce/flake-module-graph)
  draws that graph: `nix run github:NireBryce/flake-module-graph -- html --flake . > modules.html`.

## Migrating a flake that names its modules by hand

A flake where each file writes `flake.modules.<class>.<name> = …` converts
file by file:

1. **Record what each host builds**, before changing anything:
   `nix eval --raw .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath`
   for each, and the same for Home Manager generations.
2. **Unwrap each module**: `flake.modules.nixos.<name> = X;` becomes
   `nixos = X;`, and a name derived from the filename (a
   `__curPos.file` binding) goes. If the name differed from the filename,
   rename the file. Keep `{ lib, ... }:` only if the body uses `lib`.
3. **Hosts' import lists become `includes`**:
   `imports = with config.flake.modules.nixos; [ base desktop ];` becomes
   `includes.nixos = [ "base" "desktop" ];`, and `hosts.nix` refers to the
   host by its new name.
4. **References to other modules** -- `config.flake.modules.<class>.<name>`
   inside a module -- become `includes` (same class) or `enables` (another
   class); reads of the flake's own outputs become `inputs.self.…`.
5. **Compare** every drvPath with step 1. A difference with identical
   contents is usually list order: check whether a folder became a
   category, and pin it with `folderIsCategory`.

## When evaluation stops

Each message starts `error: dirs-as-categories:`, followed by the file or
folder and what is wrong.

| Message | Fix |
|---|---|
| `names used more than once: x (a/one/x.nix, a/two/x.nix)` | rename one; modules and categories share one namespace, and `x/default.nix` beside `x.nix` counts as a clash too |
| `` <file>: unknown key `nixOS`; expected one of: … `` | a typo for a class or reserved key |
| `` <file>: includes.nixos: unknown name `nope` `` | no module or category has that name; a plain folder can't be included -- include its category, or make it one |
| `` <file>: includes.nixos: `x` has no nixos module `` | the name exists, but not in that class |
| `<file>: includes.nixOS: unknown class` | a typo in the class after `includes.` |
| `` <file>: enables.homeManager: unknown name `ghost` `` | as for `includes` |
| `<folder>: files disagree on folderIsCategory` | two files in one folder set different values |
| `<folder>: folderIsCategory must be true or false` | |
| `a: a top-level folder is an area and can't be a category` | `folderIsCategory = true` on an area |
| `<file>: defaults.nix must be an attribute set, or a function of lib/inputs returning one` | a `defaults.nix` asking for `config` |

One mistake is not caught here: a file whose *only* class key is mistyped
(`{ nixOS = …; }`) has no class key, so it loads as a flake-parts module,
and flake-parts rejects the unknown option `nixOS` instead.
