# a module written as a function of lib and inputs: both reach its body
{ lib, inputs, ... }:
{
    nixos = { probe = [ (lib.concatStrings [ "fn-module:" inputs.testMarker ]) ]; };
}
