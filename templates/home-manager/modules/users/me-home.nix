# The Home Manager configuration for the user `me`: the category `shell`.
# Outside every category, so nothing includes it by accident;
# enable-home-manager.nix hands it to NixOS.
{
    includes.homeManager = [ "shell" ];

    homeManager = {
        home.stateVersion = "26.05";
    };
}
