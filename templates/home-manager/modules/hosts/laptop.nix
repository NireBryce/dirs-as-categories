# The module `laptop`: everything in the categories `base` and `desktop`,
# plus the settings below.
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
