{ ... }:
{
  services.openssh = {
    enable = true;
    # Host keys are generated fresh on every boot into the tmpfs /etc/ssh.
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  users.users.admin = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOJK/6c2cKc5d2Enb3lxb9EkSL9UriywovUz6D0Tt3QQ johannes@sage"
    ];
  };

  security.sudo.wheelNeedsPassword = false;
}
