# The Home Manager configuration for the user `me`. Outside every category,
# so nothing includes it by accident; enable-home-manager.nix hands it to NixOS.
{
    includes.homeManager = [ "shell-apps" "editors" ];

    homeManager = {
        home.stateVersion = "26.05";
    };
}
