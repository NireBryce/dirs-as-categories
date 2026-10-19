# Asks for `config`, so dirs-as-categories loads it as an ordinary
# flake-parts module. It builds each NixOS host from the module of the same name.
{ config, inputs, ... }:
{
    flake.nixosConfigurations = {
        laptop = inputs.nixpkgs.lib.nixosSystem { modules = [ config.flake.modules.nixos.laptop ]; };
        server = inputs.nixpkgs.lib.nixosSystem { modules = [ config.flake.modules.nixos.server ]; };
    };
}
