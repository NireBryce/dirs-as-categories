# base/ holds this subfolder of modules, which makes base a category.
{
    nixos = {
        services.openssh.enable = true;
        services.openssh.settings.PasswordAuthentication = false;
    };
}
