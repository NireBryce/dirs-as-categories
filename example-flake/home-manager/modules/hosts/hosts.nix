# Asks for `config`, so dirs-as-categories loads it as an ordinary
# flake-parts module. It builds the host from the module `laptop`.
{ config, inputs, ... }:
{
    flake.nixosConfigurations.laptop = inputs.nixpkgs.lib.nixosSystem {
        modules = [ config.flake.modules.nixos.laptop ];
    };
}
