# One file, two classes: the system package and the user's program.
{
    nixos = { pkgs, ... }: { environment.systemPackages = [ pkgs.ripgrep ]; };
    homeManager.programs.ripgrep.enable = true;
}
