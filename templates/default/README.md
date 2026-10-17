# Your flake

`nix flake init -t github:NireBryce/dirs-as-categories` made this flake.
Its modules come from the folder tree under `modules/`, through
[dirs-as-categories](https://github.com/NireBryce/dirs-as-categories),
which is **experimental**: `flake.nix` pins a release tag; read the
[CHANGELOG](https://github.com/NireBryce/dirs-as-categories/blob/main/CHANGELOG.md)
before you change it.

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

## Next steps

1. **Name the host.** Rename `hosts/example.nix` to your machine's name,
   say `hosts/laptop.nix`; the filename is the module's name. In
   `hosts/hosts.nix`, change both `example`s to `laptop`, and in the host
   file set `networking.hostName`.
2. **Add the hardware configuration.** Copy `/etc/nixos/hardware-configuration.nix`
   to `hosts/_laptop-hardware.nix`. The leading `_` keeps
   dirs-as-categories from reading it, because it is a NixOS module, not
   a module file. Import it from the host, and delete the placeholder
   `boot.loader` and `fileSystems` lines:

   ```nix
   nixos = {
       imports = [ ./_laptop-hardware.nix ];
       # …
   };
   ```
3. **Add the flake to git** (`git init && git add -A`): a flake sees only
   the files git knows.
4. **Build it**, then switch to it once the build succeeds:

   ```sh
   nixos-rebuild build --flake .#laptop
   sudo nixos-rebuild switch --flake .#laptop
   ```
5. **Add modules.** A new file `shared/base/fonts/fonts.nix` holding
   `{ nixos = { … }; }` is the module `fonts`, and the host gets it through
   `base` with no other change.

For Home Manager, start from `nix flake init -t github:NireBryce/dirs-as-categories#home-manager`
instead. The guide is
[Using the flake](https://github.com/NireBryce/dirs-as-categories/blob/main/wiki/using-the-flake.md);
when evaluation stops with an error, its last section says what each
message means.
