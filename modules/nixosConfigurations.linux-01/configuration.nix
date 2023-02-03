# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ pkgs
, config
, extraAuthorizedKeyFiles
, ...
}:

let
  grafana_http_port = 2342;

in
{

  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./github-runner-multi-arch.nix
    ../../shared.nix
    ../../shared-nix-settings.nix
  ];

  # set options defined by us
  hostName = "185.255.131.141";

  nix.settings.trusted-users = [ "root" "sshsession" ];

  nix.distributedBuilds = true;
  nix.buildMachines = [
    {
      hostName = "167.235.13.208";
      sshUser = "builder";
      protocol = "ssh-ng";
      system = "aarch64-darwin";
      maxJobs = 4;
      supportedFeatures = config.nix.settings.experimental-features;
    }
    {
      hostName = "167.235.13.208";
      sshUser = "builder";
      protocol = "ssh-ng";
      system = "x86_64-darwin";
      maxJobs = 4;
      supportedFeatures = config.nix.settings.experimental-features;
    }
  ];

  # Use the GRUB 2 boot loader.
  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.device = "/dev/sda"; # or "nodev" for efi only

  networking.hostName = "github-runner-host"; # Define your hostname.

  # Set your time zone.
  # time.timeZone = "Europe/Amsterdam";

  # Select internationalisation properties.
  # i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkbOptions in tty.
  # };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.github-runner = {
    uid = 1000;
    isSystemUser = true;
    createHome = false;
    group = "github-runner";
  };
  users.groups.github-runner = { };

  users.users.sshsession = {
    uid = 1001;
    isSystemUser = true;
    createHome = false;
    group = "sshsession";
  };
  users.groups.sshsession = { gid = 1001; };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    htop
    glances
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
  services.openssh.permitRootLogin = "prohibit-password";
  users.users."root".openssh.authorizedKeys = {
    keys = [ ];
    keyFiles = extraAuthorizedKeyFiles;
  };

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 80 443 ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = true;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  services.prometheus = {
    enable = true;
    port = 9001;

    retentionTime = "30d";

    exporters = {
      node = {
        enable = true;
        enabledCollectors = [ "systemd" ];
        port = 9002;
      };

    };

    scrapeConfigs = [{
      job_name = "node-scraper";
      static_configs = [{
        targets = [
          "127.0.0.1:${toString config.services.prometheus.exporters.node.port}"
        ];
      }];
    }];

  };

  # grafana configuration
  services.grafana = {
    enable = true;

    settings.server = {
      http_addr = "127.0.0.1";
      http_port = grafana_http_port;
      domain = "vmi1034228.contaboserver.net";
      root_url = "https://${config.services.grafana.settings.server.domain}";
    };
  };

  security.acme.acceptTerms = true;
  security.acme.defaults.email = "mail@noosphere.life";

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    # other Nginx options
    virtualHosts."vmi1034228.contaboserver.net" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString grafana_http_port}";
        proxyWebsockets = true; # needed if you need to use WebSocket
        extraConfig =
          # required when the target is also TLS server with multiple hosts
          "proxy_ssl_server_name on;" +
          # required when the server wants to use HTTP Authentication
          "proxy_pass_header Authorization;";
      };
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "22.11"; # Did you read the comment?
}

