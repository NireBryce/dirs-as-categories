{
    inputs = {
        nixpkgs.url     = "github:NixOS/nixpkgs/nixos-unstable";
        flake-parts.url = "github:hercules-ci/flake-parts";
        import-tree.url = "github:denful/import-tree";

        category-tree.url                     = "github:NireBryce/category-tree";
        category-tree.inputs.import-tree.follows = "import-tree";
        category-tree.inputs.flake-parts.follows = "flake-parts";
    };

    outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } {
        systems = [ "x86_64-linux" ];
        imports = [
            inputs.flake-parts.flakeModules.modules
            (inputs.category-tree.lib.tree ./modules)
        ];
    };
}
