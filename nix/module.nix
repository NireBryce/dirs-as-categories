# The flake-parts module lib.tree produces.
{ settings, root, files }:
{ lib, config, ... }:
let
    inherit (lib) filter elem optional listToAttrs nameValuePair genAttrs;
    inherit (settings) classes;

    scan = import ./scan.nix { inherit lib settings root files; };
    inherit (scan) modules categories;

    get = class: n: config.flake.modules.${class}.${n};

    # A module that names `enables` gets `enabled.<class>.<name>` among its
    # arguments. setFunctionArgs keeps the module system from looking it up
    # in _module.args, and passes every other argument through unchanged.
    enabledOf   = m: lib.mapAttrs (class: names: genAttrs names (get class)) (m.value.enables or { });
    withEnabled = m: mod:
        if !(m.value ? enables) || !builtins.isFunction mod then mod
        else lib.setFunctionArgs (args: mod (args // { enabled = enabledOf m; }))
                                 (removeAttrs (lib.functionArgs mod) [ "enabled" ]);

    # `key` makes each one load once, however many routes reach it.
    defaultsFor = q: class:
        map (D: {
            key     = "dirs-as-categories:defaults:${D.path}:${class}";
            _file   = toString D.file;
            imports = [ D.value.${class} ];
        }) (filter (D: D.value ? ${class} && scan.appliesTo D q) scan.defaults);

    moduleFor = class: m: {
        key     = "dirs-as-categories:module:${class}:${m.name}";
        _file   = toString m.file;
        imports = optional (m.value ? ${class}) (withEnabled m m.value.${class})
               ++ map (get class) (m.value.includes.${class} or [ ])
               ++ defaultsFor m.path class;
    };

    categoryFor = class: d: {
        key     = "dirs-as-categories:category:${class}:${d}";
        _file   = "${scan.rootStr}/${d}";
        imports = map (m: get class m.name) (filter (m: elem class m.classesOf) (scan.ownModules d))
               ++ map (c: get class (baseNameOf c)) (scan.nestedIn d)
               ++ defaultsFor d class;
    };
in
assert scan.checked;
{
    imports = map (e: e.file) scan.admin;

    options.flake.moduleGraph = lib.mkOption {
        description = "What dirs-as-categories built from the modules tree. Format: doc/format.md in dirs-as-categories.";
        type        = lib.types.raw;
        readOnly    = true;
    };

    config.flake.modules = genAttrs classes (class:
        listToAttrs (map (m: nameValuePair m.name (moduleFor class m)) (filter (m: elem class m.classesOf) modules)
                  ++ map (d: nameValuePair (baseNameOf d) (categoryFor class d)) categories));

    config.flake.moduleGraph = import ./publish.nix { inherit lib classes scan; };
}
