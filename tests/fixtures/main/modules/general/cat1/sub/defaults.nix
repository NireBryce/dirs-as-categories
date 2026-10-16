{ lib, ... }:
{
    nixos = { probe = [ (lib.concatStrings [ "defaults:" "sub" ]) ]; };
}
