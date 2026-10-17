{ lib, pkgs, ... }: { homeManager = { home.packages = [ pkgs.hello ]; }; }
