# Words this project uses

_Last modified: 2026-10-17_

This page defines each word the other pages use, for someone who hasn't
used Nix flakes or flake-parts before. Read it first, or come back to it
when a word on another page stops you. The exact rules are in
[`../doc/convention.md`](../doc/convention.md); reading the code itself is
covered in [`../nix/README.md`](../nix/README.md).

dirs-as-categories is **experimental**: read the [README](../README.md)'s
notice before you rely on dirs-as-categories.

## Contents

- [The tools](#the-tools)
- [What a modules tree holds](#what-a-modules-tree-holds)
- [How the parts connect](#how-the-parts-connect)

## The tools

| Word | Meaning |
|---|---|
| Nix | the language and the tool that builds packages and systems from `.nix` files |
| flake | a folder with a `flake.nix`: its `inputs` (other flakes it uses, pinned in `flake.lock`) and its `outputs` (what it builds, such as `nixosConfigurations.laptop`) |
| module | a piece of configuration that the module system merges with others. NixOS, Home Manager and nix-darwin configurations are all made of modules |
| flake-parts | a library that writes a flake's `outputs` as modules too, so a flake can be split across files |
| import-tree | a library that hands flake-parts every `.nix` file in a folder, so you never list them |
| dirs-as-categories | an import-tree preset: it reads the same folder and also names your modules and groups them, from where the files are |

## What a modules tree holds

| Word | Meaning | Example |
|---|---|---|
| class | which kind of configuration a module is for: `nixos`, `homeManager` or `darwin` | `nixos = { … };` in a file |
| module file | a file whose keys are classes (or `includes`, `enables`, `folderIsCategory`). It declares one module, named after the file | `shared/base/ssh/ssh.nix` is the module `ssh` |
| area | a top-level folder. Areas only group files and are never categories | `hosts/`, `shared/` |
| category | a folder below the top level that groups modules. Including the category includes every module beneath it. A folder is a category when one of its subfolders holds a module, or when it says so with `folderIsCategory = true` | `shared/base/` is the category `base` |
| plain folder | any other folder. It has no name; its modules belong to the category above it | `shared/base/ssh/` |
| `defaults.nix` | settings that apply whenever anything in its folder is used. Never a module, never named | `shared/base/defaults.nix` |
| admin file | any other file: dirs-as-categories hands it to flake-parts unchanged. `flake.moduleGraph` lists these as `admin` | `hosts/hosts.nix`, which builds `nixosConfigurations` |
| `_` files | files or folders whose name starts with `_`. import-tree skips them, so they can hold anything another file imports | `hosts/_laptop-hardware.nix` |

## How the parts connect

| Word | Meaning |
|---|---|
| host | a module, usually in `hosts/`, that a configuration is built from: `config.flake.modules.nixos.laptop` |
| `includes` | the modules and categories a module brings in, by name: `includes.nixos = [ "base" ];` |
| `enables` | hands a module of another class to this one, as the argument `enabled`: how a NixOS host gets a Home Manager configuration |
| home configuration | a `homeManager` module, usually in `users/`, that a host hands to Home Manager through `enables` |
| orphan | a module inside a category that nothing includes or enables. It evaluates, and installs nothing |
| `flake.modules` | where dirs-as-categories puts every module and category, by class and name. flake-parts' `flakeModules.modules` declares it |
| `flake.moduleGraph` | what dirs-as-categories built, as data: run `nix eval --json .#moduleGraph` ([format](../doc/format.md)) |

[Using the flake](using-the-flake.md) puts these together, from an empty
flake to a host with Home Manager.
