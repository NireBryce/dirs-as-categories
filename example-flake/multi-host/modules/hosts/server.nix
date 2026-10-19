# The module `server`: no desktop, plus the category `homelab`.
{
    includes.nixos = [ "base" "homelab" ];

    nixos = {
        networking.hostName  = "server";
        nixpkgs.hostPlatform = "x86_64-linux";
        system.stateVersion  = "26.05";
        boot.loader.grub.enable = false;
        fileSystems."/" = { device = "/dev/disk/by-label/nixos"; fsType = "ext4"; };
    };
}
