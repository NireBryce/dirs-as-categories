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
    # flake-parts.flakeModules.modules, the mistake it tests. One with an
    # `other/modules` folder imports that second tree too.
    mkFlake = name: flake-parts.lib.mkFlake {
        inputs = { self = { outPath = ./fixtures + "/${name}"; }; inherit flake-parts; testMarker = "from inputs"; };
    } {
        systems = [ ];
        imports = lib.optional (!lib.hasSuffix "-no-modules-import" name) flake-parts.flakeModules.modules
               ++ [ (tree (fixture name)) ]
               ++ lib.optional (builtins.pathExists (./fixtures + "/${name}/other")) (tree (./fixtures + "/${name}/other/modules"));
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
            wrapperAdmin = flake.wrapperAdminProbe or "wrapper admin NOT loaded";
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
    # The check exists only when asked for, and names each orphan with its
    # path.
    orphanCheck = mode:
        let flake = flake-parts.lib.mkFlake {
                inputs = { self = { outPath = ./fixtures/main; }; inherit flake-parts; testMarker = "x"; };
            } {
                systems = [ "x86_64-linux" ];
                imports = [ flake-parts.flakeModules.modules (tree (fixture "main"))
                            { dirsAsCategories.checkOrphans = mode; } ];
            };
        in flake.checks.x86_64-linux.module-orphans or null;

    # ── the class-contents check ────────────────────────────────────────────
    # Opt-in like the orphan check; names each module part that sets another
    # class's namespace, and nothing for namespaces that are fine.
    contentsFlake = mode: flake-parts.lib.mkFlake {
            inputs = { self = { outPath = ./fixtures/misplaced; }; inherit flake-parts; };
        } {
            systems = [ "x86_64-linux" ];
            imports = [ flake-parts.flakeModules.modules (tree (fixture "misplaced"))
                        { dirsAsCategories.checkClassContents = mode; } ];
        };
    contentsCheck = mode: (contentsFlake mode).checks.x86_64-linux.module-class-contents or null;

    # A tree with nothing misplaced, to see the eval-time check pass.
    mainChecked = mode: (flake-parts.lib.mkFlake {
            inputs = { self = { outPath = ./fixtures/main; }; inherit flake-parts; };
        } {
            systems = [ "x86_64-linux" ];
            imports = [ flake-parts.flakeModules.modules (tree (fixture "main"))
                        { dirsAsCategories.checkClassContents = mode; } ];
        }).checks.x86_64-linux.module-class-contents;

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

    # ── two trees ───────────────────────────────────────────────────────────
    # Two trees that both have an `ssh` module: the host gets both, and a
    # tree imported twice still counts once. The module system loads one
    # module per `key`, so a key that didn't name its tree would drop one.
    # With a system, so that `perSystem` (the orphan check) is evaluated too:
    # each tree used to declare the options again.
    twoTreesFlake = trees: flake-parts.lib.mkFlake {
        inputs = { self = { outPath = ./fixtures/two-trees; }; inherit flake-parts; };
    } {
        systems = [ "x86_64-linux" ];
        imports = [ flake-parts.flakeModules.modules { dirsAsCategories.checkOrphans = "build"; } ] ++ map tree trees;
    };
    treeA = ./fixtures/two-trees/a/modules;
    twoTrees = twoTreesFlake [ treeA treeA ./fixtures/two-trees/b/modules ];
    twoTreesProbe = (evalHost twoTrees "nixos" "ssh").config.probe;

    # ── a defaults.nix in the tree's root ───────────────────────────────────
    # Its folder's subtree is the whole tree, so it reaches every module and
    # category, once each.
    rootDefaults = lib.genAttrs [ "host" "c" ] (name:
        lib.sort lib.lessThan (evalHost (mkFlake "root-defaults") "nixos" name).config.probe);

    # Evaluates a flake's checks and graph fully; gives false when they fail.
    evaluates = value: (builtins.tryEval (builtins.deepSeq value value)).value;

    # ── the example flakes' trees ───────────────────────────────────────────
    # These tests build only the trees: building a host needs nixpkgs, which
    # they don't fetch.
    exampleGraph = name:
        (flake-parts.lib.mkFlake {
            inputs = { self = { outPath = ../example-flake + "/${name}"; }; inherit flake-parts; };
        } {
            systems = [ ];
            imports = [ flake-parts.flakeModules.modules (tree (../example-flake + "/${name}/modules")) ];
        }).moduleGraph;

    example = name:
        let graph = exampleGraph name; in {
            categories = lib.mapAttrs (_: category: category.members) graph.categories;
            inherit (graph) includes enables admin orphans;
        };
in
{
    inherit main force errorCases orphanCheck contentsCheck;

    # every published graph the tests build, for tests/schema.py
    graphs = {
        main                  = main.graph;
        misplaced             = (contentsFlake "build").moduleGraph;
        example-default      = exampleGraph "default";
        example-home-manager = exampleGraph "home-manager";
        example-multi-host   = exampleGraph "multi-host";
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
                              (builtins.elemAt (orphanCheck "build").args 1);
            detail = "checkOrphans: off should add no check, \"build\" should name lonely-module with its path";
        };
        orphan-check-eval = {
            ok = !(builtins.tryEval (orphanCheck "eval").drvPath).success
              && (builtins.tryEval (orphanCheck "build").drvPath).success;
            detail = "checkOrphans = \"eval\": evaluating the check should fail on lonely-module, which \"build\" leaves to the build";
        };
        class-contents-check = {
            ok = let report = builtins.elemAt (contentsCheck "build").args 1; in
                 contentsCheck false == null
              && lib.hasInfix "a/c/one/jq.nix: the `nixos` part sets `home`, which is a Home Manager option namespace" report
              && lib.hasInfix "a/c/one/loader.nix: the `homeManager` part sets `fileSystems`, which is a NixOS option namespace" report
              && lib.hasInfix "a/c/one/hw.nix: the `darwin` part sets `boot`, which is a NixOS option namespace" report
              && lib.hasInfix "a/c/one/hw.nix: the `darwin` part sets `hardware`" report
              && !lib.hasInfix "fine.nix" report;
            detail = "checkClassContents: off should add no check, on should name jq.nix and loader.nix but not fine.nix";
        };
        misplaced-published = {
            ok = let published = (contentsFlake "build").moduleGraph.misplaced or null; in
                 published != null
              && lib.length published == 4
              && lib.any (lib.hasInfix "a/c/one/jq.nix: the `nixos` part sets `home`") published
              && lib.all (lib.hasInfix "a/c/one/") published
              && !((contentsFlake false).moduleGraph ? misplaced)
              && !(main.graph ? misplaced);
            detail = "flake.moduleGraph.misplaced: the check's messages while checkClassContents is on, and absent otherwise";
        };
        class-contents-check-eval = {
            ok = !(builtins.tryEval (contentsCheck "eval").drvPath).success
              && (contentsFlake "eval").moduleGraph ? misplaced
              && (builtins.tryEval (mainChecked "eval").drvPath).success;
            detail = "checkClassContents = \"eval\": evaluating the check should fail on the misplaced fixture and pass on a tree with none; the graph still lists misplaced";
        };
        classes = {
            ok = classesWith (tree.addClasses [ "nixOnDroid" ]) == {
                    classes = [ "nixos" "homeManager" "darwin" "nixOnDroid" ];
                    names   = { nixos = [ "c" "x" ]; homeManager = [ "c" ]; darwin = [ "c" ]; nixOnDroid = [ "c" "x" ]; };
                }
              && (classesWith (tree.withClasses [ "nixos" "nixOnDroid" ])).classes == [ "nixos" "nixOnDroid" ];
            detail = "addClasses [ \"nixOnDroid\" ]: ${builtins.toJSON (classesWith (tree.addClasses [ "nixOnDroid" ]))}";
        };
        two-trees = {
            ok     = lib.sort lib.lessThan twoTreesProbe == [ "ssh from tree a" "ssh from tree b" ];
            detail = "two trees with an `ssh` module each, tree a imported twice: ${builtins.toJSON twoTreesProbe}";
        };
        two-trees-checks = {
            ok = let onceGraph = evaluates (twoTreesFlake [ treeA ]).moduleGraph; in
                 evaluates (builtins.attrNames twoTrees.checks.x86_64-linux) == [ "module-orphans" ]
              && onceGraph != false && evaluates (twoTreesFlake [ treeA treeA ]).moduleGraph == onceGraph;
            detail = "two trees: the orphan check should evaluate, and a tree imported twice should publish the graph it publishes once";
        };
        root-defaults = {
            ok     = rootDefaults == { host = [ "host" "root defaults" "x" ]; c = [ "root defaults" "x" "y" ]; };
            detail = "a defaults.nix in the root should reach every module and category once: ${builtins.toJSON rootDefaults}";
        };
        example-default = {
            ok = example "default" == {
                categories = { base = [ "locale" "ssh" ]; };
                includes   = { example.nixos = [ "base" ]; };
                enables    = { };
                admin      = [ "hosts/hosts.nix" ];
                orphans    = [ ];
            };
            detail = "example-flake/default/modules: ${builtins.toJSON (example "default")}";
        };
        example-home-manager = {
            ok = example "home-manager" == {
                categories = { base = [ "enable-home-manager" "locale" "ssh" ]; desktop = [ "plasma" ]; shell = [ "bash" "git" ]; };
                includes   = { laptop.nixos = [ "base" "desktop" ]; me-home.homeManager = [ "shell" ]; };
                enables    = { enable-home-manager.homeManager = [ "me-home" ]; };
                admin      = [ "hosts/hosts.nix" ];
                orphans    = [ ];
            };
            detail = "example-flake/home-manager/modules: ${builtins.toJSON (example "home-manager")}";
        };
        example-multi-host = {
            ok = example "multi-host" == {
                categories = {
                    base       = [ "boot-generations" "enable-home-manager" "locale" "flakes" ];
                    desktop    = [ "kde-base" "kde-desktop" ];
                    editors    = [ "micro" ];
                    homelab    = [ "backup" "reverse-proxy" ];
                    macos      = [ "dock" ];
                    packages   = [ "git" ];
                    shell-apps = [ "fzf" "ripgrep" ];
                    text-tools = [ "bat" "less" ];
                };
                includes   = {
                    kde-desktop.nixos = [ "kde-base" ];
                    laptop.nixos = [ "base" "packages" "kde-desktop" ];
                    mac.darwin = [ "base" "macos" ];
                    me-home.homeManager = [ "shell-apps" "editors" ];
                    server.nixos = [ "base" "homelab" ];
                };
                enables    = { enable-home-manager.homeManager = [ "me-home" ]; };
                admin      = [ "hosts/hosts.nix" ];
                orphans    = [ ];
            };
            detail = "example-flake/multi-host/modules: ${builtins.toJSON (example "multi-host")}";
        };
    };
}
