# imported by wrapper-admin.nix; import-tree skips it (leading `_`). Its
# keys depend on `self`, which is a stand-in while dirs-as-categories scans.
{ self, lib, ... }:
lib.optionalAttrs (self ? outPath) {
    flake.wrapperAdminProbe = "wrapper admin loaded";
}
