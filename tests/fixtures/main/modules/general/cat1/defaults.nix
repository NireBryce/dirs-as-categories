{ nixos = { lib, ... }: { probe = [ "defaults:cat1" ]; scalar = lib.mkDefault "cat1-default"; }; }
