# a flake-parts module whose top level uses an argument that exists only
# once flake-parts runs: the scan's peek must give up quietly, not fail
{ flake-parts-lib, lib, ... }:
flake-parts-lib.mkTransposedPerSystemModule {
    name   = "forcingAdminProbe";
    option = lib.mkOption { type = lib.types.str; default = "forcing admin loaded"; };
    file   = ./forcing-admin.nix;
}
