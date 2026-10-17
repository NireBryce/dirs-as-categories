{
    description = "Modules and categories from a folder tree: an import-tree preset for flake-parts (experimental)";

    inputs = {
        import-tree.url = "github:denful/import-tree";
        # The tests evaluate fixture trees with it; a flake using lib.tree has its own.
        flake-parts.url = "github:hercules-ci/flake-parts";
    };

    outputs = { import-tree, flake-parts, ... }:
        let
            lib     = flake-parts.inputs.nixpkgs-lib.lib;
            systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
            tree    = import ./nix { importTree = import-tree; };
            tests   = import ./tests { inherit lib flake-parts tree; };

            # A passing test is a derivation that only writes $out; a failing
            # one stops evaluation with its detail.
            check = system: name: test:
                if test.ok then builtins.derivation {
                    inherit system;
                    name    = "dirs-as-categories-test-${name}";
                    builder = "/bin/sh";
                    args    = [ "-c" "echo ok > $out" ];
                }
                else throw "dirs-as-categories test ${name} failed: ${test.detail}";
        in
        {
            lib.tree = tree;

            templates.default = {
                path        = ./templates/default;
                description = "A flake-parts flake whose modules come from dirs-as-categories";
            };
            templates.home-manager = {
                path        = ./templates/home-manager;
                description = "A NixOS host with Home Manager, modules from dirs-as-categories";
            };

            checks = lib.genAttrs systems (system: lib.mapAttrs (check system) tests.checks);

            # for tests/errors.py and for looking at results by hand
            tests = { inherit (tests) main errorCases force; };
        };
}
