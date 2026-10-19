{
    nixos = { pkgs, ... }: { environment.systemPackages = [ pkgs.git ]; };
    homeManager.programs.git.enable = true;
}
