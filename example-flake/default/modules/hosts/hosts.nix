# A function, so dirs-as-categories loads it as an ordinary flake-parts module.
{ config, inputs, ... }:
{
    flake.nixosConfigurations.example = inputs.nixpkgs.lib.nixosSystem {
        modules = [ config.flake.modules.nixos.example ];
    };
}
