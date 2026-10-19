# Applies whenever anything in base/ is reached. Not a module itself.
{
    nixos = { lib, ... }: {
        time.timeZone = lib.mkDefault "UTC";
    };
}
