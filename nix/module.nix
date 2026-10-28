# nix/module.nix: the flake-parts module `lib.tree` returns.
#
# nix/scan.nix has decided what every file is; this file builds the result:
#   flake.modules.<class>.<name>  one module per module file and per category
#   imports                       every other file, as an ordinary flake-parts module
#   dirsAsCategories.trees        this tree's graph (nix/publish.nix) and orphans,
#                                 which nix/shared.nix publishes once per flake
#
# The first line takes what nix/default.nix passes in; the second is the
# flake-parts module itself, which the module system calls with `config`
# and the rest.
{ settings, root, files, treeKey }:
{ lib, config, options, inputs, ... }:
let
    inherit (lib) filter optional listToAttrs nameValuePair genAttrs;
    inherit (settings) classes;

    scan = import ./scan.nix { inherit lib inputs settings root files; };
    inherit (scan) modules categories;

    # Another module from `flake.modules`, by class and name. Reading
    # `config` here is safe: it happens only when the module system asks
    # for a module's contents, long after the names were decided.
    get = class: name: config.flake.modules.${class}.${name};

    # ── enables ─────────────────────────────────────────────────────────────
    # A file with `enables.homeManager = [ "my-home" ];` gets the argument
    # `enabled.homeManager.my-home` in its class modules:
    #   nixos = { enabled, ... }: { home-manager.users.me = enabled.homeManager.my-home; };
    #
    # The module system fills a module's arguments by name, and would look
    # `enabled` up in `_module.args`, where it doesn't exist. So the class
    # module is wrapped: the wrapper adds `enabled` itself, and
    # `setFunctionArgs` tells the module system the wrapper wants the same
    # arguments as the original, minus `enabled`.
    enabledOf   = mod: lib.mapAttrs (class: names: genAttrs names (get class)) (mod.value.enables or { });
    withEnabled = mod: classModule:
        if !(mod.value ? enables) || !builtins.isFunction classModule then classModule
        else lib.setFunctionArgs (args: classModule (args // { enabled = enabledOf mod; }))
                                 (removeAttrs (lib.functionArgs classModule) [ "enabled" ]);

    # ── the modules ─────────────────────────────────────────────────────────
    # Each module below is a set of `imports`, plus two attributes the
    # module system reads:
    #   key    -- a module with the same `key` is loaded only once per
    #             configuration, however many routes import it. This is what
    #             lets a host include both a category and a module inside it.
    #             Each key names the tree's root, so two trees that both
    #             have an `ssh` module both load: the module system would
    #             otherwise keep whichever came first and drop the other.
    #   _file  -- the file named in error messages and in
    #             `options.<x>.definitionsWithLocations`: the user's file,
    #             not this one.

    # The defaults.nix files that apply to `target` (a module's path or a
    # category's folder), for one class.
    defaultsFor = target: class:
        map (defaultsFile: {
            key     = "dirs-as-categories:${scan.rootStr}:defaults:${defaultsFile.path}:${class}";
            _file   = toString defaultsFile.file;
            imports = [ defaultsFile.value.${class} ];
        }) (filter (defaultsFile: defaultsFile.value ? ${class} && scan.appliesTo defaultsFile target) scan.defaults);

    # A module file, in one class: its own class part (if it has one), what
    # it includes, and the defaults.nix files that apply to it.
    moduleFor = class: mod: {
        key     = "dirs-as-categories:${scan.rootStr}:module:${class}:${mod.name}";
        _file   = toString mod.file;
        imports = optional (mod.value ? ${class}) (withEnabled mod mod.value.${class})
               ++ map (get class) (mod.value.includes.${class} or [ ])
               ++ defaultsFor mod.path class;
    };

    # A category, in one class: its own modules, the categories directly
    # nested in it (which import theirs in turn), and its defaults.nix files.
    categoryFor = class: category: {
        key     = "dirs-as-categories:${scan.rootStr}:category:${class}:${category}";
        _file   = "${scan.rootStr}/${category}";
        imports = map (mod: get class mod.name) (filter (scan.hasClass class) (scan.ownModules category))
               ++ map (nested: get class (baseNameOf nested)) (scan.nestedIn category)
               ++ defaultsFor category class;
    };

    # ── the modules import ──────────────────────────────────────────────────
    # `flake.modules` gets its type -- modules that merge -- from
    # flake-parts.flakeModules.modules. Without that import, a tree alone
    # happens to work, but the first other definition of `flake.modules`
    # ends in a bare "infinite recursion encountered". The check is lazy and
    # runs when something reads `flake.modules`, because `options`, like
    # `config`, can't be read at the top of a module.
    hasModulesOption = options.flake.type.getSubOptions [ ] ? modules;
    needsModulesImport = "dirs-as-categories: flake.modules has no type: "
        + "add inputs.flake-parts.flakeModules.modules to imports, beside lib.tree";

    # ── the orphans, for the orphan check in nix/shared.nix ─────────────────
    pathOf = name: (lib.findFirst (mod: mod.name == name) null modules).path;
in
# Raise the errors that need the whole tree (name clashes, unknown names in
# `includes`/`enables`) before anything else is built.
assert scan.checked;
{
    # nix/shared.nix declares the options every tree shares; its `key` loads
    # it once however many trees import it.
    imports = [ { key = "dirs-as-categories:shared"; imports = [ ./shared.nix ]; } ]
           ++ map (entry: entry.file) scan.admin;

    config = {
        # flake.modules.<class> = { <module name> = …; <category name> = …; }
        flake.modules = lib.throwIfNot hasModulesOption needsModulesImport (genAttrs classes (class:
            listToAttrs (map (mod: nameValuePair mod.name (moduleFor class mod)) (scan.modulesOf class)
                      ++ map (category: nameValuePair (baseNameOf category) (categoryFor class category)) categories)));

        dirsAsCategories.trees.${treeKey} = {
            root    = scan.rootStr;
            graph   = import ./publish.nix { inherit lib classes scan; };
            orphans = map (name: "${name} (${pathOf name})") scan.orphans;
            inherit (scan) misplaced;
        };
    };
}
