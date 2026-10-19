# Applies whenever anything in base/ is reached. Not a module itself.
{ lib, ... }:
{
    nixos = {
        time.timeZone = lib.mkDefault "UTC";
    };
}
