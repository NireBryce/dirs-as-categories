{ config, ... }: { nixos = { networking.hostName = config.x; }; }
