{
    enables.homeManager = [ "hm-agg" "enabled-thing" ];
    nixos = { enabled, lib, pkgs, inputs, ... }: {
        imports = [ inputs.extraModule ];                       # a special argument used in imports
        probe = [ "enabled:${lib.concatStringsSep "," (builtins.attrNames enabled.homeManager)}"
                  "pkgs:${pkgs.marker}" ];
    };
}
