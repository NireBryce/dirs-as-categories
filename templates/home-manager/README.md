# Your flake

`nix flake init -t github:NireBryce/dirs-as-categories#home-manager` made
this flake: a NixOS host, `laptop`, whose user `me` gets a Home Manager
configuration. Its modules come from the folder tree under `modules/`,
through [dirs-as-categories](https://github.com/NireBryce/dirs-as-categories),
which is **experimental**: keep it pinned in `flake.lock` and read what
changed before you update it.

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

## Next steps

1. **Name the host and the user.** Rename `hosts/laptop.nix` to your
   machine's name; the filename is the module's name. Change `laptop` in
   `hosts/hosts.nix` to match, and `networking.hostName` in the host file.
   Replace `me` in `enable-home-manager.nix` with your user name.
2. **Add the hardware configuration.** Copy `/etc/nixos/hardware-configuration.nix`
   to `hosts/_laptop-hardware.nix`. The leading `_` keeps
   dirs-as-categories from reading it, because it is a NixOS module, not
   a module file. Add `imports = [ ./_laptop-hardware.nix ];` to the host's
   `nixos`, and delete the placeholder `boot.loader` and `fileSystems` lines.
3. **Add the flake to git** (`git init && git add -A`): a flake sees only
   the files git knows.
4. **Build it**, then switch to it once the build succeeds:

   ```sh
   nixos-rebuild build --flake .#laptop
   sudo nixos-rebuild switch --flake .#laptop
   ```

The guide is
[Using the flake](https://github.com/NireBryce/dirs-as-categories/blob/main/wiki/using-the-flake.md);
this tree is its worked example, and its last section says what each error
message means.
