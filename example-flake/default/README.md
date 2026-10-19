# Example flake: one host, one category

This flake illustrates the smallest tree: one host and one category, with all
modules coming from the folder tree under `modules/` through
[dirs-as-categories](../../README.md). The host has placeholder file systems
and no user.
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
