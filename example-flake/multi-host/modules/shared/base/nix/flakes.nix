{
    nixos.nix.settings.experimental-features = [ "nix-command" "flakes" ];
    homeManager.nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
