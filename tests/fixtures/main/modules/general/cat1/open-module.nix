# names no arguments: called early, and its class key makes it a module file
args: { nixos.probe = [ "open-module (${args.inputs.testMarker})" ]; }
