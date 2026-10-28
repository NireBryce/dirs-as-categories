{ nixos = { fileSystems.x = 1; networking = { }; }; homeManager = { home.packages = [ ]; }; darwin = { networking = { }; }; }
