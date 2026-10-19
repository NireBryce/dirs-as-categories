# A stand-in for a real desktop: a file in /etc keeps the build light.
{ nixos.environment.etc."model/desktop".text = "kde"; }
