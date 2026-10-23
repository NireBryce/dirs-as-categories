# Names no arguments, so it is called with stand-ins; its keys are visible,
# so it is a module file, and its class part reads a stand-in.
args: {
    includes.nixos = [ "x" ];
    nixos = args.config.foo;
}
