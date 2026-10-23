# base/ holds this subfolder of modules, which makes base a category.
{
    nixos = {
        services.openssh = {
            enable = true;
            # Allow key login only. Both settings are needed: with PAM,
            # keyboard-interactive login asks for a password too. Add your key to
            # users.users.<name>.openssh.authorizedKeys.keys before relying on it.
            settings.PasswordAuthentication = false;
            settings.KbdInteractiveAuthentication = false;
        };
    };
}
