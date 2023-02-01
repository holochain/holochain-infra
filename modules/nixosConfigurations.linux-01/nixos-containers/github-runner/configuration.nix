{ pkgs

, githubRunnerHolochainHolochainTokenFile
, name
, extraLabels

  # not used explicitly
, lib
, specialArgs
, config
, options
, modulesPath
}: {
  boot.isContainer = true;

  # disabledModules = [ "services/continuous-integration/github-runner.nix" ];
  imports = [
    # inputs.nixos-fhs-compat.nixosModules.combined
    # "${inputs.nixpkgs-ghrunner}/nixos/modules/services/continuous-integration/github-runner.nix"
    # "${inputs.nixpkgs-ghrunner}/nixos/modules/services/continuous-integration/github-runners.nix"

    ../../../../shared-nix-settings.nix
  ];

  nix.settings.trusted-users = [ "root" "github-runner-${name}" "sshsession" ];

  environment.systemPackages = with pkgs; [
    coreutils
    libressl.nc
    procps
    cachix
    xz
    zstd
    openssh
    tree
    tmux
    upterm
    gawk
    gitFull
    vim
  ];

  services.github-runner =
    let
      mkHolochainRunner = args:
        ({
          enable = true;
          replace = true;
          ephemeral = false;
          # user = "github-runner";
          url = "https://github.com/holochain/holochain";
          tokenFile = githubRunnerHolochainHolochainTokenFile;
          package = pkgs.github-runner.overrideAttrs
            ({ postInstall ? "", buildInputs ? [ ], ... }: {
              postInstall = postInstall + ''
                ln -s ${pkgs.nodejs-16_x} $out/externals/node12
              '';
            });

          extraPackages =
            # add a dummy script for commands that won't work in this runner
            (builtins.map
              (elem:
                pkgs.writeShellScriptBin "${elem}"
                  "echo wanted to run: ${elem} \${@}") [ "sudo" "apt-get" "apt" ]
            ++ config.environment.systemPackages);

          inherit extraLabels;

          # serviceOverrides = {
          #   RuntimeDirectoryPreserve=false;
          #   # CapabilityBoundingSet = "CAP_SYS_ADMIN";
          #   DynamicUser = false;

          #   NoNewPrivileges = false;
          #   PrivateDevices = false;
          #   PrivateMounts = false;
          #   PrivateTmp = false;
          #   PrivateUsers = false;
          #   ProtectClock = false;
          #   ProtectControlGroups = false;
          #   ProtectHome = false;
          #   ProtectHostname = false;
          #   ProtectKernelLogs = false;
          #   ProtectKernelModules = false;
          #   ProtectKernelTunables = false;
          #   ProtectSystem = "";
          #   RemoveIPC = false;
          #   RestrictNamespaces = false;
          #   RestrictRealtime = false;
          #   RestrictSUIDSGID = false;
          #   UMask = "0066";
          #   ProtectProc = "invisible";

          #   SystemCallFilter = [];
          #   InaccessiblePaths = [];

          #   Environment="SYSTEMD_LOG_LEVEL=debug COMPlus_EnableDiagnostics=0";
          # };
        } // args);
    in
    mkHolochainRunner { inherit name; };
  #{
  # r0 = mkHolochainRunner { name = "nixos-r0"; };
  # r1 = mkHolochainRunner { name = "nixos-r1"; };
  #};

  # Activation scripts for impure set up of paths in /
  system.activationScripts.bin = ''
    echo "setting up /bin..."
    mkdir -p /bin
    ln -sfT /bin/sh /bin/.bash
    mv -Tf /bin/.bash /bin/bash
  '';
  system.activationScripts.lib64 = ''
    echo "setting up /lib64..."
    mkdir -p /lib64
    ln -sfT ${pkgs.glibc}/lib/ld-linux-x86-64.so.2 /lib64/.ld-linux-x86-64.so.2
    mv -Tf /lib64/.ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2
  '';

  # environment.fhs.enable = true;
  # environment.fhs.linkLibs = true;
  # environment.lsb.enable = true;
  # environment.lsb.support32Bit = true;

  users.users.github-runner = {
    uid = 1000;
    isSystemUser = true;
    createHome = false;
    group = "github-runner";
  };
  users.groups.github-runner = { gid = 1000; };

  users.users.sshsession = {
    uid = 1001;
    isSystemUser = true;
    createHome = false;
    group = "sshsession";
  };
  users.groups.sshsession = { gid = 1001; };

  systemd.services.sshsession = {
    enable = true;
    description = "sshsession service";

    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network.target" "network-online.target" ];

    path = config.environment.systemPackages;

    environment = {
      HOME = "%t/sshsession";
      TMUX_TMPDIR = "%t/sshsession/.tmux_tmpdir";
      SHELL = "${pkgs.bashInteractive}/bin/bash";
    };

    serviceConfig = {
      ExecStart = pkgs.writeShellScript "sshsession-execstart" ''
        set -x
        env

        pwd

        rm -rf ~/.ssh ''${TMUX_TMPDIR:?}

        mkdir -p ~/.ssh
        mkdir -p ''${TMUX_TMPDIR:?}

        echo -e 'y\n'|ssh-keygen -q -t rsa -N "" -f ~/.ssh/id_rsa
        echo -e 'y\n'|ssh-keygen -q -t ed25519 -N "" -f ~/.ssh/id_ed25519
        cat <<-EOF > ~/.ssh/config
        Host uptermd.upterm.dev
          IdentityFile $HOME/.ssh/id_ed25519
          UserKnownHostsFile $HOME/.ssh/known_hosts
          StrictHostKeyChecking no
          CheckHostIP no
          TCPKeepAlive yes
          ServerAliveInterval 30
          ServerAliveCountMax 180
          VerifyHostKeyDNS yes
          UpdateHostKeys yes
          PasswordAuthentication no
        EOF
        cat ~/.ssh/config
        ssh -vv -tt \
          -F ~/.ssh/config \
          uptermd.upterm.dev || true
        cat <(cat ~/.ssh/known_hosts | awk '{ print "@cert-authority * " $2 " " $3 }') >> ~/.ssh/known_hosts
        cat ~/.ssh/known_hosts

        # run upterm in the outer session and give it some time to spawn
        tmux new -s outer -d
        tmux send-keys -t outer.0 "upterm host --github-user steveeJ --force-command 'tmux attach -t inner'" ENTER
        sleep 2

        # detach the outer session
        tmux send-keys -t outer.0 q C-m

        # resize terminal for largest client by default
        tmux set -t outer window-size largest

        # for debugging
        tree -apugs ~/

        upterm session current --admin-socket ~/.upterm/*.sock

        set +x
        while true; do
          set -e
          if ! tmux ls | grep inner >/dev/null 2>&1; then
            tmux new -s inner -d
            tmux set -t inner window-size largest
          fi

          upterm session current --admin-socket ~/.upterm/*.sock >/dev/null 2>&1

          sleep 1
        done
      '';

      ExecStop = pkgs.writeShellScript "sshsession-execstop" ''
        tmux kill-server
        pkill -9 upterm
      '';

      Restart = "always";

      RuntimeDirectory = "sshsession";
      RuntimeDirectoryPreserve = false;
      WorkingDirectory = "%t/sshsession";

      InaccessiblePaths = [ ];

      # By default, use a dynamically allocated user
      DynamicUser = true;
      # User = "sshsession";

      KillSignal = "SIGINT";

      # Hardening (may overlap with DynamicUser=)
      # The following options are only for optimizing:
      # systemd-analyze security github-runner
      AmbientCapabilities = "";
      CapabilityBoundingSet = "";
      DeviceAllow = "/dev/tty";
      NoNewPrivileges = true;
      PrivateDevices = true;
      PrivateMounts = true;
      PrivateTmp = true;
      PrivateUsers = true;
      ProtectClock = true;
      ProtectControlGroups = true;
      ProtectHome = true;
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectSystem = "strict";
      RemoveIPC = true;
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      UMask = "0066";
      ProtectProc = "invisible";
      SystemCallFilter = [
        "~@clock"
        "~@cpu-emulation"
        "~@module"
        "~@mount"
        "~@obsolete"
        "~@raw-io"
        "~@reboot"
        "~capset"
        "~setdomainname"
        "~sethostname"
      ];
      RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" "AF_NETLINK" ];

      # Needs network access
      PrivateNetwork = false;
      # Cannot be true due to Node
      MemoryDenyWriteExecute = false;

      # The more restrictive "pid" option makes `nix` commands in CI emit
      # "GC Warning: Couldn't read /proc/stat"
      # You may want to set this to "pid" if not using `nix` commands
      # ProcSubset = "all";
      # Coverage programs for compiled code such as `cargo-tarpaulin` disable
      # ASLR (address space layout randomization) which requires the
      # `personality` syscall
      # You may want to set this to `true` if not using coverage tooling on
      # compiled code
      LockPersonality = false;
    };

  };

  system.stateVersion = "22.11";
}
