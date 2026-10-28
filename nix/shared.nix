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

    # A derivation that only writes $out, or fails with `report`. It needs no
    # nixpkgs, so a flake using this pays nothing for it. `"build"` fails in
    # the builder, so only building the check fails (`nix flake check
    # --no-build` passes). `"eval"` throws while the derivation's arguments
    # are evaluated, which `--no-build` does too.
    checkDerivation = system: name: mode: problems: report: builtins.derivation {
        inherit system name;
        builder = "/bin/sh";
        args    = [ "-c" (
            if problems == [ ] then "echo none > $out"
            else if mode == "eval" then throw report
            else "echo ${lib.escapeShellArg report} >&2; exit 1") ];
    };

    checkMode = lib.types.enum [ false "build" "eval" ];
in
{
    options = {
        dirsAsCategories = {
            checkOrphans = lib.mkOption {
                description = ''
                    Add `checks.<system>.module-orphans`, which fails while any module
                    inside a category is reached by no `includes` or `enables` --
                    valid, evaluated, and installing nothing. `false` (the default)
                    adds no check. `"build"` fails when the check is built, so
                    `nix flake check --no-build` passes over an orphan. `"eval"`
                    fails while the check is evaluated, so `--no-build` catches it
                    too. The list is `flake.moduleGraph.orphans` in every mode.
                '';
                type    = checkMode;
                default = false;
                example = "eval";
            };

            checkClassContents = lib.mkOption {
                description = ''
                    Add `checks.<system>.module-class-contents`, which fails while a
                    class part sets an option namespace that only another class has
                    (`home` under `nixos`, say). A heuristic over a short list of
                    namespaces, so it is off by default (`false`). `"build"` and
                    `"eval"` fail as for `checkOrphans`. While either is set,
                    `flake.moduleGraph.misplaced` lists the messages.
                '';
                type    = checkMode;
                default = false;
                example = "eval";
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
        # `flake.moduleGraph.misplaced` is published only when the check is on: finding it
        # calls the class parts' functions, which a flake without the check
        # never pays for or risks (see nix/scan.nix, section 8).
        flake.moduleGraph =
            if lib.length trees == 1
            then (builtins.head trees).graph
                 // lib.optionalAttrs (config.dirsAsCategories.checkClassContents != false) { inherit misplaced; }
            else throw onlyOneTree;

        perSystem = { system, ... }: {
            checks = lib.mkMerge [
                (lib.mkIf (config.dirsAsCategories.checkClassContents != false) {
                    module-class-contents = checkDerivation system "module-class-contents"
                        config.dirsAsCategories.checkClassContents misplaced (lib.concatStringsSep "\n" misplaced);
                })
                (lib.mkIf (config.dirsAsCategories.checkOrphans != false) {
                    module-orphans = checkDerivation system "module-orphans"
                        config.dirsAsCategories.checkOrphans orphans orphanReport;
                })
            ];
        };
    };
}
