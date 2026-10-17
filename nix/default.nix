# nix/default.nix: `lib.tree`, the entry point a flake imports.
#
#   imports = [ (inputs.dirs-as-categories.lib.tree ./modules) ];
#   imports = [ (inputs.dirs-as-categories.lib.tree.withClasses [ "nixos" "homeManager" "darwin" "nixOnDroid" ] ./modules) ];
#
# import-tree finds the files (every `.nix`, skipping paths with a `_`
# component) and hands the list to ./module.nix, which turns it into one
# flake-parts module. nix/README.md describes how the files fit together.
{ importTree }:
let
    defaults = { classes = [ "nixos" "homeManager" "darwin" ]; };

    # import-tree's `pipeTo` collects the files under `root`, then calls the
    # function with the list instead of importing each one.
    make = settings: root:
        importTree.pipeTo (files: {
            _file   = "${toString root} (dirs-as-categories)";
            imports = [ (import ./module.nix { inherit settings root files; }) ];
        }) root;
in
{
    # `__functor` makes this set callable like a function, so `lib.tree ./modules`
    # works while `lib.tree.withClasses` is still an attribute of it.
    __functor   = _: make defaults;
    withClasses = classes: make (defaults // { inherit classes; });
}
