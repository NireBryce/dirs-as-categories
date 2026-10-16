# Tests, as plain values: `nix flake check` turns each into a check, and
# tests/errors.py uses `force` to read the error messages (a Nix check can
# only see that evaluation failed, not what it said).
#
# Each fixture is a modules tree. Its modules add strings to a `probe` list,
# so evaluating a host shows what reached it, and how many times.
{ lib, flake-parts, tree }:
let
    fixture = name: ./fixtures + "/${name}/modules";

    mkFlake = name: flake-parts.lib.mkFlake {
        inputs = { self = { outPath = ./fixtures + "/${name}"; }; inherit flake-parts; testMarker = "from inputs"; };
    } {
        systems = [ ];
        imports = [ flake-parts.flakeModules.modules (tree (fixture name)) ];
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
                let ev = evalHost flake class name; in {
                    probe  = ev.config.probe;
                    scalar = ev.config.scalar;
                    files  = map (d: lib.removePrefix prefix d.file) ev.options.probe.definitionsWithLocations;
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

    # ── the template's tree ─────────────────────────────────────────────────
    # Only the tree: building its host needs nixpkgs, which these tests don't
    # fetch.
    template =
        let flake = flake-parts.lib.mkFlake {
                inputs = { self = { outPath = ../templates/default; }; inherit flake-parts; };
            } {
                systems = [ ];
                imports = [ flake-parts.flakeModules.modules (tree ../templates/default/modules) ];
            };
            g = flake.moduleGraph;
        in {
            categories = builtins.attrNames g.categories;
            members    = g.categories.base.members;
            inherit (g) includes admin;
        };
in
{
    inherit main force errorCases orphanCheck;

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
        template = {
            ok = template == {
                categories = [ "base" ];
                members    = [ "locale" "ssh" ];
                includes   = { example.nixos = [ "base" ]; };
                admin      = [ "hosts/hosts.nix" ];
            };
            detail = "templates/default/modules: ${builtins.toJSON template}";
        };
    };
}
