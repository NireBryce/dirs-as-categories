{
    description = "Modules and categories from a folder tree: an import-tree preset for flake-parts";

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
            check = system: name: t:
                if t.ok then builtins.derivation {
                    inherit system;
                    name    = "category-tree-test-${name}";
                    builder = "/bin/sh";
                    args    = [ "-c" "echo ok > $out" ];
                }
                else throw "category-tree test ${name} failed: ${t.detail}";
        in
        {
            lib.tree = tree;

            templates.default = {
                path        = ./templates/default;
                description = "A flake-parts flake whose modules come from category-tree";
            };

            checks = lib.genAttrs systems (system: lib.mapAttrs (check system) tests.checks);

            # for tests/errors.py and for looking at results by hand
            tests = { inherit (tests) main errorCases force; };
        };
}
