# Tests, as plain values: `nix flake check` turns each into a check, and
# tests/errors.py uses `force` to read the error messages (a Nix check can
# only see that evaluation failed, not what it said).
#
# Each fixture is a modules tree. Its modules add strings to a `probe` list,
# so evaluating a host shows what reached it, and how many times.
{ lib, flake-parts, tree }:
let
    fixture = name: ./fixtures + "/${name}/modules";

    # A fixture whose name ends in -no-modules-import is evaluated without
    # flake-parts.flakeModules.modules, the mistake it tests.
    mkFlake = name: flake-parts.lib.mkFlake {
        inputs = { self = { outPath = ./fixtures + "/${name}"; }; inherit flake-parts; testMarker = "from inputs"; };
    } {
        systems = [ ];
        imports = lib.optional (!lib.hasSuffix "-no-modules-import" name) flake-parts.flakeModules.modules
               ++ [ (tree (fixture name)) ];
    };

    probeModule = { lib, ... }: {
        options.probe  = lib.mkOption { type = lib.types.listOf lib.types.str; default = [ ]; };
        options.scalar = lib.mkOption { type = lib.types.str; default = "unset"; };
        config._module.args.pkgs = { marker = "from _module.args"; };
    };

    evalHost = flake: class: name: lib.evalModules {
        specialArgs = { inputs.extraModule = { probe = [ "special-arg import" ]; }; };
        modules     = [ probeModule flake.modules.${class}.${name} ];
    };

    # ── main fixture ────────────────────────────────────────────────────────
    main =
        let
            flake = mkFlake "main";
            prefix = "${toString (fixture "main")}/";
            run = class: name:
                let evaluated = evalHost flake class name; in {
                    probe  = evaluated.config.probe;
                    scalar = evaluated.config.scalar;
                    files  = map (definition: lib.removePrefix prefix definition.file) evaluated.options.probe.definitionsWithLocations;
                };
        in {
            names = lib.mapAttrs (_: builtins.attrNames) flake.modules;
            admin = flake.adminProbe or "admin NOT loaded";
            configAdmin = flake.configAdminProbe or "config admin NOT loaded";
            plainAdmin = flake.plainAdminProbe or "plain admin NOT loaded";
            hosts = lib.genAttrs [ "h1" "h2" "h3" "h4" "h5" ] (run "nixos");
            hm    = run "homeManager" "hm-agg";
            graph = flake.moduleGraph;
        };

    expected = lib.importJSON ./expected/main.json;

    # ── error fixtures ──────────────────────────────────────────────────────
    errorCases = builtins.attrNames (lib.importJSON ./errors.json);

    # Everything a mistake could hide in: the graph, every module name, and
    # the host when the fixture has one.
    force = name:
        let
            flake = mkFlake name;
            host  = if flake.modules.nixos ? host then (evalHost flake "nixos" "host").config.probe else null;
        in builtins.deepSeq [ flake.moduleGraph (lib.mapAttrs (_: builtins.attrNames) flake.modules) host ] true;

    unexpectedlyFine = lib.filter (name: (builtins.tryEval (force name)).success) errorCases;

    # ── the orphan check ────────────────────────────────────────────────────
    # Present only when asked for, and naming each orphan with its path.
    orphanCheck = on:
        let flake = flake-parts.lib.mkFlake {
                inputs = { self = { outPath = ./fixtures/main; }; inherit flake-parts; testMarker = "x"; };
            } {
                systems = [ "x86_64-linux" ];
                imports = [ flake-parts.flakeModules.modules (tree (fixture "main"))
                            { dirsAsCategories.checkOrphans = on; } ];
            };
        in flake.checks.x86_64-linux.module-orphans or null;

    # ── extra classes ───────────────────────────────────────────────────────
    # addClasses keeps the default classes; withClasses replaces them.
    classesWith = make:
        let flake = flake-parts.lib.mkFlake {
                inputs = { self = { outPath = ./fixtures/classes; }; inherit flake-parts; };
            } {
                systems = [ ];
                imports = [ flake-parts.flakeModules.modules (make (fixture "classes")) ];
            };
        in { inherit (flake.moduleGraph) classes; names = lib.mapAttrs (_: builtins.attrNames) flake.modules; };

    # ── the templates' trees ────────────────────────────────────────────────
    # Only the trees: building a host needs nixpkgs, which these tests don't
    # fetch.
    templateGraph = name:
        (flake-parts.lib.mkFlake {
            inputs = { self = { outPath = ../templates + "/${name}"; }; inherit flake-parts; };
        } {
            systems = [ ];
            imports = [ flake-parts.flakeModules.modules (tree (../templates + "/${name}/modules")) ];
        }).moduleGraph;

    template = name:
        let graph = templateGraph name; in {
            categories = lib.mapAttrs (_: category: category.members) graph.categories;
            inherit (graph) includes enables admin orphans;
        };
in
{
    inherit main force errorCases orphanCheck;

    # every published graph the tests build, for tests/schema.py
    graphs = {
        main                  = main.graph;
        template-default      = templateGraph "default";
        template-home-manager = templateGraph "home-manager";
    };

    checks = {
        main = {
            ok     = main == expected;
            detail = "tests/fixtures/main differs from tests/expected/main.json. Got:\n${builtins.toJSON main}";
        };
        errors = {
            ok     = unexpectedlyFine == [ ];
            detail = "these error fixtures evaluated without an error: ${lib.concatStringsSep ", " unexpectedlyFine}";
        };
        orphan-check = {
            ok = orphanCheck false == null
              && lib.hasInfix "lonely-module (general/lonely/inner/lonely-module.nix)"
                              (builtins.elemAt (orphanCheck true).args 1);
            detail = "checkOrphans: off should add no check, on should name lonely-module with its path";
        };
        classes = {
            ok = classesWith (tree.addClasses [ "nixOnDroid" ]) == {
                    classes = [ "nixos" "homeManager" "darwin" "nixOnDroid" ];
                    names   = { nixos = [ "c" "x" ]; homeManager = [ "c" ]; darwin = [ "c" ]; nixOnDroid = [ "c" "x" ]; };
                }
              && (classesWith (tree.withClasses [ "nixos" "nixOnDroid" ])).classes == [ "nixos" "nixOnDroid" ];
            detail = "addClasses [ \"nixOnDroid\" ]: ${builtins.toJSON (classesWith (tree.addClasses [ "nixOnDroid" ]))}";
        };
        template = {
            ok = template "default" == {
                categories = { base = [ "locale" "ssh" ]; };
                includes   = { example.nixos = [ "base" ]; };
                enables    = { };
                admin      = [ "hosts/hosts.nix" ];
                orphans    = [ ];
            };
            detail = "templates/default/modules: ${builtins.toJSON (template "default")}";
        };
        template-home-manager = {
            ok = template "home-manager" == {
                categories = { base = [ "enable-home-manager" "locale" "ssh" ]; desktop = [ "plasma" ]; shell = [ "bash" "git" ]; };
                includes   = { laptop.nixos = [ "base" "desktop" ]; me-home.homeManager = [ "shell" ]; };
                enables    = { enable-home-manager.homeManager = [ "me-home" ]; };
                admin      = [ "hosts/hosts.nix" ];
                orphans    = [ ];
            };
            detail = "templates/home-manager/modules: ${builtins.toJSON (template "home-manager")}";
        };
    };
}
