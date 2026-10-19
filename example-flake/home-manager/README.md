# Example flake: a host with Home Manager

A flake whose modules come from the folder tree under `modules/`: a NixOS host, `laptop`, whose user `me` gets a Home Manager configuration. It uses
[dirs-as-categories](../../README.md), which is **experimental**, and is
here to read, evaluate and draw: not a configuration to copy or switch a
machine to, since its host has placeholder file systems and no user to
log in as.
[How it works, on the example flake](../../wiki/using-the-flake.md#how-it-works-on-the-example-flake)
walks through this example, file by file.

```
modules/
├─ hosts/
│  ├─ hosts.nix                     builds nixosConfigurations.laptop (an ordinary flake-parts module)
│  └─ laptop.nix                    the host: includes base, desktop
├─ users/
│  └─ me-home.nix                   the Home Manager configuration: includes shell
└─ shared/
   ├─ base/                         a category
   │  ├─ defaults.nix               applies whenever anything in base/ is used
   │  ├─ locale.nix
   │  ├─ ssh/ssh.nix
   │  └─ home-manager/enable-home-manager.nix   hands me-home to Home Manager
   ├─ shell/                        a category: git, bash
   └─ desktop/                      a category: plasma
```

From a clone of this repository:

```sh
nix eval --json --no-write-lock-file ./example-flake/home-manager#moduleGraph
nix run github:NireBryce/flake-module-graph/v0.1.0 -- html --flake ./example-flake/home-manager > modules.html
```
