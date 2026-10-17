# as nixos-generate-config writes it
{ config, lib, pkgs, modulesPath, ... }:
{
    imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];
    boot.initrd.availableKernelModules = [ "nvme" ];
}
