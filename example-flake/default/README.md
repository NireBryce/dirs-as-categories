# Example flake: one host, one category

A small flake whose modules come from the folder tree under `modules/`. It uses
[dirs-as-categories](../../README.md), which is **experimental**, and is
here to read, evaluate and draw: not a configuration to copy or switch a
machine to, since its host has placeholder file systems and no user to
log in as.
[How it works, on the example flake](../../wiki/using-the-flake.md#how-it-works-on-the-example-flake)
walks through the larger example beside this one, [`../home-manager/`](../home-manager/).

```
modules/
├─ hosts/
│  ├─ hosts.nix          builds nixosConfigurations.example (an ordinary flake-parts module)
│  └─ example.nix        the host: includes the category base
└─ shared/
   └─ base/              a category: its subfolder ssh/ holds a module
      ├─ defaults.nix    applies whenever anything in base/ is used
      ├─ locale.nix      the module `locale`
      └─ ssh/ssh.nix     the module `ssh`
```

From a clone of this repository:

```sh
nix eval --json --no-write-lock-file ./example-flake/default#moduleGraph
nix run github:NireBryce/flake-module-graph/v0.1.0 -- html --flake ./example-flake/default > modules.html
```
