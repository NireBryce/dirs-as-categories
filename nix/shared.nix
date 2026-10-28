# nix/shared.nix: what a flake gets once, however many trees it imports.
#
# Every tree's module (nix/module.nix) imports this file under one `key`,
# so the module system loads it once: an option declared by two modules is
# an error ("is already declared"). Each tree reports what it built in
# `dirsAsCategories.trees`; this file turns the reports into
# `flake.moduleGraph` and the orphan check.
{ lib, config, ... }:
let
    # [ { root = "/nix/store/…/modules"; graph = …; orphans = [ "<name> (<path>)" … ]; } … ]
    trees   = lib.attrValues config.dirsAsCategories.trees;
    orphans = lib.concatMap (tree: tree.orphans) trees;
    misplaced = lib.concatMap (tree: tree.misplaced) trees;

    onlyOneTree = "dirs-as-categories: flake.moduleGraph describes one modules tree, "
        + "and this flake imports ${toString (lib.length trees)}: "
        + lib.concatMapStringsSep ", " (tree: tree.root) trees;

    orphanReport = "dirs-as-categories: reached by no includes or enables (include it, "
        + "or a category above it): " + lib.concatStringsSep ", " orphans;
in
{
    options = {
        dirsAsCategories = {
            checkOrphans = lib.mkOption {
                description = ''
                    Add `checks.<system>.module-orphans`, which fails while any module
                    inside a category is reached by no `includes` or `enables` --
                    valid, evaluated, and installing nothing. The list is
                    `flake.moduleGraph.orphans` either way.
                '';
                type    = lib.types.bool;
                default = false;
            };

            checkClassContents = lib.mkOption {
                description = ''
                    Add `checks.<system>.module-class-contents`, which fails while a
                    class part sets an option namespace that only another class has
                    (`home` under `nixos`, say). A heuristic over a short list of
                    namespaces, so it is off by default.
                '';
                type    = lib.types.bool;
                default = false;
            };

            trees = lib.mkOption {
                description = "What each imported tree built, by tree key. Internal: read `flake.moduleGraph`.";
                type        = lib.types.lazyAttrsOf lib.types.raw;
                default     = { };
                internal    = true;
            };
        };

        flake.moduleGraph = lib.mkOption {
            description = "What dirs-as-categories built from the modules tree. Format: doc/format.md in dirs-as-categories.";
            type        = lib.types.raw;
            readOnly    = true;
        };
    };

    config = {
        flake.moduleGraph =
            if lib.length trees == 1 then (builtins.head trees).graph else throw onlyOneTree;

        # A derivation that only writes $out, or fails naming the orphans. It
        # needs no nixpkgs, so a flake using this pays nothing for it.
        perSystem = { system, ... }: {
            checks = lib.mkMerge [ (lib.mkIf config.dirsAsCategories.checkClassContents {
                module-class-contents = builtins.derivation {
                    inherit system;
                    name    = "module-class-contents";
                    builder = "/bin/sh";
                    args    = [ "-c" (
                        if misplaced == [ ] then "echo none > $out"
                        else "echo ${lib.escapeShellArg (lib.concatStringsSep "\n" misplaced)} >&2; exit 1") ];
                };
            }) (lib.mkIf config.dirsAsCategories.checkOrphans {
                module-orphans = builtins.derivation {
                    inherit system;
                    name    = "module-orphans";
                    builder = "/bin/sh";
                    args    = [ "-c" (
                        if orphans == [ ] then "echo none > $out"
                        else "echo ${lib.escapeShellArg orphanReport} >&2; exit 1") ];
                };
            }) ];
        };
    };
}
