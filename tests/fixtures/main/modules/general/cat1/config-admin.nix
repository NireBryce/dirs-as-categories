# asks for config: never called by dirs-as-categories, loaded as a flake-parts module
{ config, ... }:
{
    flake.configAdminProbe = "config admin loaded";
}
