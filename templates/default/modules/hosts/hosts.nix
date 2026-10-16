# A function, so category-tree loads it as an ordinary flake-parts module.
{ config, inputs, ... }:
{
    flake.nixosConfigurations.example = inputs.nixpkgs.lib.nixosSystem {
        modules = [ config.flake.modules.nixos.example ];
    };
}
