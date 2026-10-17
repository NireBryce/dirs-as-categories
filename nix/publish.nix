# nix/publish.nix: `flake.moduleGraph`, format version 1 (doc/format.md).
#
# The tree nix/scan.nix read, as plain data for tools such as
# flake-module-graph. Paths are relative to the modules root; names are the
# ones `includes` and hosts use. Changing what a field means is a change to
# the format: see "The contract with flake-module-graph" in AGENTS.md.
{ lib, classes, scan }:
let
    inherit (lib) filter elem listToAttrs nameValuePair;

    # { <module name> = <that module's value for key>; } for each module
    # that has `key`:  byModule "includes" == { laptop = { nixos = [ "base" ]; }; }
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

    # plain folders: below the top level, and not categories
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

    # files loaded as ordinary flake-parts modules
    admin = map (entry: entry.path) scan.admin;

    # modules inside a category that no `includes`/`enables` reaches
    inherit (scan) orphans;
}
