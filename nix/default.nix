# lib.tree: an import-tree preset.
#
#   imports = [ (inputs.category-tree.lib.tree ./modules) ];
#   imports = [ (inputs.category-tree.lib.tree.withClasses [ "nixos" "homeManager" "darwin" "nixOnDroid" ] ./modules) ];
#
# import-tree finds the files (`.nix`, no `/_` paths) and hands the list to
# ./module.nix, which turns it into one flake-parts module.
{ importTree }:
let
    defaults = { classes = [ "nixos" "homeManager" "darwin" ]; };

    make = settings: root:
        importTree.pipeTo (files: {
            _file   = "${toString root} (category-tree)";
            imports = [ (import ./module.nix { inherit settings root files; }) ];
        }) root;
in
{
    __functor   = _: make defaults;
    withClasses = classes: make (defaults // { inherit classes; });
}
