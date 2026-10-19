# The module `mac`: a darwin-class module. Nothing builds it (that needs
# nix-darwin); it is here so the tree has all three classes.
{
    includes.darwin = [ "base" "macos" ];

    darwin = {
        networking.hostName = "mac";
    };
}
