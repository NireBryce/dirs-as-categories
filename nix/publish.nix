# flake.moduleGraph, format version 1 (doc/format.md). Paths are relative to
# the modules root; names are what `includes` and hosts use.
{ lib, classes, scan }:
let
    inherit (lib) filter elem listToAttrs nameValuePair;

    # each module that has `key`, by name, with its value
    byModule = key: listToAttrs (map (mod: nameValuePair mod.name mod.value.${key})
                                     (filter (mod: mod.value ? ${key}) scan.modules));
in
{
    version = 1;
    inherit classes;

    categories = listToAttrs (map (category: nameValuePair (baseNameOf category) {
        dir     = category;
        members = map (mod: mod.name) (scan.ownModules category);
        nested  = map baseNameOf (scan.nestedIn category);
        flag    = scan.flagOf category;
    }) scan.categories);

    folders = map (dir: { inherit dir; flag = scan.flagOf dir; })
                  (filter (dir: !scan.isTopLevel dir && !(elem dir scan.categories)) scan.folders);

    modules = listToAttrs (map (mod: nameValuePair mod.name {
        inherit (mod) path;
        classes = mod.classesOf;
    }) scan.modules);

    includes = byModule "includes";
    enables  = byModule "enables";

    defaults = map (defaultsFile: scan.defaultsReach defaultsFile // {
        inherit (defaultsFile) path;
        classes = filter (class: defaultsFile.value ? ${class}) classes;
    }) scan.defaults;

    admin = map (entry: entry.path) scan.admin;

    # modules inside a category that no `includes`/`enables` reaches
    inherit (scan) orphans;
}
