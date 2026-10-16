# An attribute set, so it is a module named `example` (its filename).
{
    includes.nixos = [ "base" ];

    nixos = {
        networking.hostName  = "example";
        nixpkgs.hostPlatform = "x86_64-linux";
        system.stateVersion  = "26.05";
        boot.loader.grub.enable = false;
        fileSystems."/" = { device = "/dev/disk/by-label/nixos"; fsType = "ext4"; };
    };
}
