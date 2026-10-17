# One module in two classes: a host that includes it gets the nixos part,
# a Home Manager configuration the homeManager part.
{
    nixos       = { programs.bash.completion.enable = true; };
    homeManager = { programs.bash.enable = true; };
}
