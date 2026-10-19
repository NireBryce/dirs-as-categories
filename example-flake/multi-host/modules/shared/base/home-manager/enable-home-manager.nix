# Turns on Home Manager and gives the user `me` the module `me-home`.
{ inputs, ... }:
{
    enables.homeManager = [ "me-home" ];

    nixos = { enabled, ... }: {
        imports = [ inputs.home-manager.nixosModules.home-manager ];

        users.users.me.isNormalUser = true;
        home-manager.users.me = enabled.homeManager.me-home;
    };
}
