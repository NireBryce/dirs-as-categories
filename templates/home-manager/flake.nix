{
    # dirs-as-categories is experimental: keep it pinned in flake.lock and read
    # what changed before updating it.
    inputs = {
        nixpkgs.url     = "github:NixOS/nixpkgs/nixos-unstable";
        flake-parts.url = "github:hercules-ci/flake-parts";
        import-tree.url = "github:denful/import-tree";

        home-manager = {
            url = "github:nix-community/home-manager";
            inputs.nixpkgs.follows = "nixpkgs";
        };

        dirs-as-categories = {
            url = "github:NireBryce/dirs-as-categories";
            inputs = {
                import-tree.follows = "import-tree";
                flake-parts.follows = "flake-parts";
            };
        };
    };

    outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } {
        systems = [ "x86_64-linux" ];
        imports = [
            inputs.flake-parts.flakeModules.modules
            (inputs.dirs-as-categories.lib.tree ./modules)
        ];
    };
}
