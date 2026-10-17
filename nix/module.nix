# nix/module.nix: the flake-parts module `lib.tree` returns.
#
# nix/scan.nix has decided what every file is; this file builds the result:
#   flake.modules.<class>.<name>  one module per module file and per category
#   flake.moduleGraph             the same tree as data (nix/publish.nix)
#   imports                       every other file, as an ordinary flake-parts module
#
# The first line takes what nix/default.nix passes in; the second is the
# flake-parts module itself, which the module system calls with `config`
# and the rest.
{ settings, root, files }:
{ lib, config, inputs, ... }:
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
    #   _file  -- the file named in error messages and in
    #             `options.<x>.definitionsWithLocations`: the user's file,
    #             not this one.

    # The defaults.nix files that apply to `target` (a module's path or a
    # category's folder), for one class.
    defaultsFor = target: class:
        map (defaultsFile: {
            key     = "dirs-as-categories:defaults:${defaultsFile.path}:${class}";
            _file   = toString defaultsFile.file;
            imports = [ defaultsFile.value.${class} ];
        }) (filter (defaultsFile: defaultsFile.value ? ${class} && scan.appliesTo defaultsFile target) scan.defaults);

    # A module file, in one class: its own class part (if it has one), what
    # it includes, and the defaults.nix files that apply to it.
    moduleFor = class: mod: {
        key     = "dirs-as-categories:module:${class}:${mod.name}";
        _file   = toString mod.file;
        imports = optional (mod.value ? ${class}) (withEnabled mod mod.value.${class})
               ++ map (get class) (mod.value.includes.${class} or [ ])
               ++ defaultsFor mod.path class;
    };

    # A category, in one class: its own modules, the categories directly
    # nested in it (which import theirs in turn), and its defaults.nix files.
    categoryFor = class: category: {
        key     = "dirs-as-categories:category:${class}:${category}";
        _file   = "${scan.rootStr}/${category}";
        imports = map (mod: get class mod.name) (filter (scan.hasClass class) (scan.ownModules category))
               ++ map (nested: get class (baseNameOf nested)) (scan.nestedIn category)
               ++ defaultsFor category class;
    };

    # ── the orphan check ────────────────────────────────────────────────────
    pathOf = name: (lib.findFirst (mod: mod.name == name) null modules).path;
    orphanReport = "dirs-as-categories: reached by no includes or enables (include it, "
        + "or a category above it): "
        + lib.concatMapStringsSep ", " (name: "${name} (${pathOf name})") scan.orphans;
in
# Raise the errors that need the whole tree (name clashes, unknown names in
# `includes`/`enables`) before anything else is built.
assert scan.checked;
{
    imports = map (entry: entry.file) scan.admin;

    options.dirsAsCategories.checkOrphans = lib.mkOption {
        description = ''
            Add `checks.<system>.module-orphans`, which fails while any module
            inside a category is reached by no `includes` or `enables` --
            valid, evaluated, and installing nothing. The list is
            `flake.moduleGraph.orphans` either way.
        '';
        type    = lib.types.bool;
        default = false;
    };

    options.flake.moduleGraph = lib.mkOption {
        description = "What dirs-as-categories built from the modules tree. Format: doc/format.md in dirs-as-categories.";
        type        = lib.types.raw;
        readOnly    = true;
    };

    config = {
        # flake.modules.<class> = { <module name> = …; <category name> = …; }
        flake.modules = genAttrs classes (class:
            listToAttrs (map (mod: nameValuePair mod.name (moduleFor class mod)) (scan.modulesOf class)
                      ++ map (category: nameValuePair (baseNameOf category) (categoryFor class category)) categories));

        flake.moduleGraph = import ./publish.nix { inherit lib classes scan; };

        # A derivation that only writes $out, or fails naming the orphans: no
        # nixpkgs needed, so it costs a flake using this nothing.
        perSystem = { system, ... }: {
            checks = lib.mkIf config.dirsAsCategories.checkOrphans {
                module-orphans = builtins.derivation {
                    inherit system;
                    name    = "module-orphans";
                    builder = "/bin/sh";
                    args    = [ "-c" (
                        if scan.orphans == [ ] then "echo none > $out"
                        else "echo ${lib.escapeShellArg orphanReport} >&2; exit 1") ];
                };
            };
        };
    };
}
