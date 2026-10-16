{ enables.homeManager = [ "ghost" ]; nixos = { enabled, ... }: { probe = builtins.attrNames enabled.homeManager; }; }
