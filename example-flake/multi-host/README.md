# Example flake: several hosts, nested categories

This flake illustrates a tree shaped like a real multi-host flake, built with
[dirs-as-categories](../../README.md). It shows nested categories, hosts that
pick categories, Home Manager reached through `enables`, and all three classes
in one tree. The hosts are placeholders: services are files in `/etc` and the
only packages are `ripgrep` and `git`, so evaluating a host is quick.

```
modules/
├─ hosts/
│  ├─ hosts.nix                 builds nixosConfigurations.laptop and .server (an ordinary flake-parts module)
│  ├─ laptop.nix                a host: includes base, packages, kde-desktop
│  ├─ server.nix                a host: includes base, homelab
│  └─ mac.nix                   a darwin-class module (nothing builds it)
├─ users/
│  └─ me-home.nix               the Home Manager configuration: includes shell-apps, editors
├─ _lib/helpers.nix             ignored: a leading `_` keeps a path out of the tree
└─ shared/
   ├─ base/                     a category
   │  ├─ defaults.nix           applies whenever anything in base/ is used
   │  └─ boot/, nix/, home-manager/, locale.nix
   ├─ packages/                 a category containing three more
   │  ├─ shell-apps/            a category containing text-tools/ (and pagers/ below it)
   │  ├─ editors/
   │  └─ development/
   ├─ desktop/kde/              kde-desktop includes kde-base
   ├─ homelab/services/         a category only the server uses
   └─ macos/dock.nix            a category because the file sets `folderIsCategory`
```

`just examples`, from the repository root, evaluates the `laptop` and
`server` hosts of this flake with real nixpkgs and home-manager. `mac`
needs nix-darwin, so nothing builds it. To evaluate by hand, from a
clone of this repository:

```sh
nix eval --json --no-write-lock-file --override-input dirs-as-categories "path:$PWD" \
    ./example-flake/multi-host#moduleGraph
nix eval --raw --no-write-lock-file --override-input dirs-as-categories "path:$PWD" \
    ./example-flake/multi-host#nixosConfigurations.laptop.config.system.build.toplevel.drvPath
```
