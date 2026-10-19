# nix/default.nix: `lib.tree`, the entry point a flake imports.
#
#   imports = [ (inputs.dirs-as-categories.lib.tree ./modules) ];
#   imports = [ (inputs.dirs-as-categories.lib.tree.addClasses [ "nixOnDroid" ] ./modules) ];   # the defaults, and more
#   imports = [ (inputs.dirs-as-categories.lib.tree.withClasses [ "nixos" ] ./modules) ];       # exactly these
#
# import-tree finds the files (every `.nix`, skipping paths with a `_`
# component) and hands the list to ./module.nix, which turns it into one
# flake-parts module. nix/README.md describes how the files fit together.
{ importTree }:
let
    defaults = { classes = [ "nixos" "homeManager" "darwin" ]; };

    # import-tree's `pipeTo` collects the files under `root`, then calls the
    # function with the list instead of importing each one. The `key` makes
    # the module system load a tree imported twice (with the same classes)
    # once; `treeKey` also names the tree in `dirsAsCategories.trees`.
    make = settings: root:
        let treeKey = "dirs-as-categories:tree:${toString root}:${builtins.concatStringsSep "," settings.classes}"; in
        importTree.pipeTo (files: {
            key     = treeKey;
            _file   = "${toString root} (dirs-as-categories)";
            imports = [ (import ./module.nix { inherit settings root files treeKey; }) ];
        }) root;
in
{
    # `__functor` makes this set callable like a function, so `lib.tree ./modules`
    # works while `lib.tree.withClasses` is still an attribute of it.
    __functor   = _: make defaults;
    addClasses  = extra: make (defaults // { classes = defaults.classes ++ extra; });
    withClasses = classes: make (defaults // { inherit classes; });
}
