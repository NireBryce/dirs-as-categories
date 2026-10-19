# names no arguments and hands them on: dirs-as-categories can't see what it
# needs, so it gets stand-ins too; its keys depend on `self`, so it is a
# flake-parts module
args: import ./_wrapped.nix args
