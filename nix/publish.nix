# flake.moduleGraph, format version 1 (doc/format.md). Paths are relative to
# the modules root; names are what `includes` and hosts use.
{ lib, classes, scan }:
let
    inherit (lib) filter elem listToAttrs nameValuePair;
in
{
    version = 1;
    inherit classes;

    categories = listToAttrs (map (d: nameValuePair (baseNameOf d) {
        dir     = d;
        members = map (m: m.name) (scan.ownModules d);
        nested  = map baseNameOf (scan.nestedIn d);
        flag    = scan.flagOf d;
    }) scan.categories);

    folders = map (d: { dir = d; flag = scan.flagOf d; })
                  (filter (d: scan.depth d >= 2 && !(elem d scan.categories)) scan.folders);

    modules = listToAttrs (map (m: nameValuePair m.name {
        inherit (m) path;
        classes = m.classesOf;
    }) scan.modules);

    includes = listToAttrs (map (m: nameValuePair m.name m.value.includes) (filter (m: m.value ? includes) scan.modules));
    enables  = listToAttrs (map (m: nameValuePair m.name m.value.enables)  (filter (m: m.value ? enables)  scan.modules));

    defaults = map (D: scan.defaultsReach D // {
        inherit (D) path;
        classes = filter (c: D.value ? ${c}) classes;
    }) scan.defaults;

    admin = map (e: e.path) scan.admin;

    # modules inside a category that no `includes`/`enables` reaches
    inherit (scan) orphans;
}
