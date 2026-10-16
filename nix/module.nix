# The flake-parts module lib.tree produces.
{ settings, root, files }:
{ lib, config, inputs, ... }:
let
    inherit (lib) filter optional listToAttrs nameValuePair genAttrs;
    inherit (settings) classes;

    scan = import ./scan.nix { inherit lib inputs settings root files; };
    inherit (scan) modules categories;

    get = class: name: config.flake.modules.${class}.${name};

    # A module that names `enables` gets `enabled.<class>.<name>` among its
    # arguments. setFunctionArgs keeps the module system from looking it up
    # in _module.args, and passes every other argument through unchanged.
    enabledOf   = mod: lib.mapAttrs (class: names: genAttrs names (get class)) (mod.value.enables or { });
    withEnabled = mod: classModule:
        if !(mod.value ? enables) || !builtins.isFunction classModule then classModule
        else lib.setFunctionArgs (args: classModule (args // { enabled = enabledOf mod; }))
                                 (removeAttrs (lib.functionArgs classModule) [ "enabled" ]);

    # `key` makes each one load once, however many routes reach it.
    defaultsFor = target: class:
        map (defaultsFile: {
            key     = "dirs-as-categories:defaults:${defaultsFile.path}:${class}";
            _file   = toString defaultsFile.file;
            imports = [ defaultsFile.value.${class} ];
        }) (filter (defaultsFile: defaultsFile.value ? ${class} && scan.appliesTo defaultsFile target) scan.defaults);

    moduleFor = class: mod: {
        key     = "dirs-as-categories:module:${class}:${mod.name}";
        _file   = toString mod.file;
        imports = optional (mod.value ? ${class}) (withEnabled mod mod.value.${class})
               ++ map (get class) (mod.value.includes.${class} or [ ])
               ++ defaultsFor mod.path class;
    };

    categoryFor = class: category: {
        key     = "dirs-as-categories:category:${class}:${category}";
        _file   = "${scan.rootStr}/${category}";
        imports = map (mod: get class mod.name) (filter (scan.hasClass class) (scan.ownModules category))
               ++ map (nested: get class (baseNameOf nested)) (scan.nestedIn category)
               ++ defaultsFor category class;
    };

    pathOf = name: (lib.findFirst (mod: mod.name == name) null modules).path;
    orphanReport = "dirs-as-categories: reached by no includes or enables (include it, "
        + "or a category above it): "
        + lib.concatMapStringsSep ", " (name: "${name} (${pathOf name})") scan.orphans;
in
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
