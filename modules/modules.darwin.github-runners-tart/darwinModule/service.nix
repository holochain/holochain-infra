{ config
, lib
, pkgs

, cfg ? config.services.github-runner
, svcName
, currentConfigTokenFilename ? ".current-token"

, ...
}:

with lib;

let
  baseDir = "${config.users.users.github-runner.home}/${svcName}";
  workDir =  "${baseDir}/work";
  stateDir = "${baseDir}/state";
  logsDir = "${baseDir}/logs";
  # Does the following, sequentially:
  # - If the module configuration or the token has changed, purge the state directory,
  #   and create the current and the new token file with the contents of the configured
  #   token. While both files have the same content, only the later is accessible by
  #   the service user.
  # - Configure the runner using the new token file. When finished, delete it.
  # - Set up the directory structure by creating the necessary symlinks.
  setupScript =
    let
      # Wrapper script which expects the full path of the state, working and logs
      # directory as arguments.
      writeScript = name: lines: pkgs.writeShellScript "${svcName}-${name}.sh" ''
        set -euo pipefail
        set -x

        STATE_DIRECTORY="$1"
        WORK_DIRECTORY="$2"
        LOGS_DIRECTORY="$3"

        mkdir -p $STATE_DIRECTORY $WORK_DIRECTORY $LOGS_DIRECTORY

        ${lines}
      '';
      runnerRegistrationConfig = {
        name = svcName;
        inherit (cfg)
          tokenFile
          url
          runnerGroup
          extraLabels
          ephemeral
          baseDir;
      };
      newConfigPath = builtins.toFile "${svcName}-config.json" (builtins.toJSON runnerRegistrationConfig);
      currentConfigPath = "$STATE_DIRECTORY/.nixos-current-config.json";
      newConfigTokenPath = "$STATE_DIRECTORY/.new-token";
      currentConfigTokenPath = "$STATE_DIRECTORY/${currentConfigTokenFilename}";

      runnerCredFiles = [
        ".credentials"
        ".credentials_rsaparams"
        ".runner"
      ];
      unconfigureRunner = writeScript "unconfigure" ''
        copy_tokens() {
          # Copy the configured token file to the state dir and allow the service user to read the file
          ${pkgs.coreutils}/bin/install --mode=666 $TOKEN_FILE "${newConfigTokenPath}"
          # Also copy current file to allow for a diff on the next start
          ${pkgs.coreutils}/bin/install --mode=600 $TOKEN_FILE "${currentConfigTokenPath}"
        }
        clean_state() {
          ${pkgs.findutils}/bin/find "$STATE_DIRECTORY/" -mindepth 1 -delete
          copy_tokens
        }
        diff_config() {
          changed=0
          # Check for module config changes
          [[ -f "${currentConfigPath}" ]] \
            && ${pkgs.diffutils}/bin/diff -q '${newConfigPath}' "${currentConfigPath}" >/dev/null 2>&1 \
            || changed=1
          # Also check the content of the token file
          [[ -f "${currentConfigTokenPath}" ]] \
            && ${pkgs.diffutils}/bin/diff -q "${currentConfigTokenPath}" $TOKEN_FILE >/dev/null 2>&1 \
            || changed=1
          # If the config has changed, remove old state and copy tokens
          if [[ "$changed" -eq 1 ]]; then
            echo "Config has changed, removing old runner state."
            echo "The old runner will still appear in the GitHub Actions UI." \
                  "You have to remove it manually."
            clean_state
          fi
        }
        if [[ "${optionalString cfg.ephemeral "1"}" ]]; then
          # In ephemeral mode, we always want to start with a clean state
          clean_state
        elif [[ "$(ls -A "$STATE_DIRECTORY")" ]]; then
          # There are state files from a previous run; diff them to decide if we need a new registration
          diff_config
        else
          # The state directory is entirely empty which indicates a first start
          copy_tokens
        fi
      '';
      configureRunner = writeScript "configure" ''
        if [[ -e "${newConfigTokenPath}" ]]; then
          echo "Configuring GitHub Actions Runner"
          args=(
            --unattended
            --disableupdate
            --work "$WORK_DIRECTORY"
            --url ${escapeShellArg cfg.url}
            --labels ${escapeShellArg (concatStringsSep "," cfg.extraLabels)}
            --name ${escapeShellArg svcName}
            ${optionalString cfg.replace "--replace"}
            ${optionalString (cfg.runnerGroup != null) "--runnergroup ${escapeShellArg cfg.runnerGroup}"}
            ${optionalString cfg.ephemeral "--ephemeral"}
          )
          # If the token file contains a PAT (i.e., it starts with "ghp_" or "github_pat_"), we have to use the --pat option,
          # if it is not a PAT, we assume it contains a registration token and use the --token option
          token=$(<"${newConfigTokenPath}")
          if [[ "$token" =~ ^ghp_* ]] || [[ "$token" =~ ^github_pat_* ]]; then
            args+=(--pat "$token")
          else
            args+=(--token "$token")
          fi
          ${cfg.package}/bin/config.sh "''${args[@]}"
          # Move the automatically created _diag dir to the logs dir
          mkdir -p  "$STATE_DIRECTORY/_diag"
          cp    -r  "$STATE_DIRECTORY/_diag/." "$LOGS_DIRECTORY/"
          rm    -rf "$STATE_DIRECTORY/_diag/"
          # Cleanup token from config
          rm "${newConfigTokenPath}"
          # Symlink to new config
          ln -s '${newConfigPath}' "${currentConfigPath}"
        fi
      '';
      setupWorkDir = writeScript "setup-work-dirs" ''
        # Cleanup previous service
        ${pkgs.findutils}/bin/find -H "$WORK_DIRECTORY" -mindepth 1 -delete

        # Link _diag dir
        ln -s "$LOGS_DIRECTORY" "$WORK_DIRECTORY/_diag"

        # Link the runner credentials to the work dir
        ln -s "$STATE_DIRECTORY"/{${lib.concatStringsSep "," runnerCredFiles}} "$WORK_DIRECTORY/"
      '';
    in
      lib.concatStringsSep "\n"
      (map (x: "${x} ${escapeShellArgs [ stateDir workDir logsDir ]}") [
        unconfigureRunner
        configureRunner
        setupWorkDir
      ]);

  start = pkgs.writeScript "start-github-runner" ''
    set -x
    ${setupScript}
    ${cfg.package}/bin/Runner.Listener run --startuptype service
  '';

  runnerTarball = pkgs.callPackage (pkgs.path + /nixos/lib/make-system-tarball.nix) {
    fileName = "github-runner";
    storeContents = [
      {object=start; symlink=null;}
      {object=pkgs.cacert; symlink=null;}
    ];
    contents = [];
    compressCommand = "pixz -t -1";
  };

  scriptGuest = pkgs.writeScript "guest.sh" ''
    set -euo pipefail
    set -x

    # set up env
    export runnerTarball="$PWD/github-runner.tar.xz"
    export RUNNER_ROOT=${stateDir}
    export HOME=${baseDir}
    export USER=$(whoami)
    export NIX_SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
    export PATH="/nix/var/nix/profiles/default/bin:$PATH"
    export PATH="/nix/var/nix/profiles/per-user/$USER/profile/bin:$PATH"

    # populate nix.conf
    echo "trusted-users = root $USER" > nix.conf
    echo "experimental-features = nix-command flakes" >> nix.conf

    # install nix
    sh <(curl -L https://releases.nixos.org/nix/nix-2.12.0/install) \
      --daemon \
      --no-channel-add \
      --darwin-use-unencrypted-nix-store-volume \
      --daemon-user-count 8 \
      --nix-extra-conf-file ./nix.conf

    # make /nix writable and push the github runner app to the store
    sudo mount -uw /nix
    cd / && sudo tar xf $runnerTarball nix/

    # ensure the working directories do exist and are owned by the user
    sudo mkdir -p ${baseDir}
    sudo chown -R $(whoami) ${baseDir}
    cd $HOME && ${start}
  '';

  cirrucConf = pkgs.writeText ".cirrus.yml" ''
    task:
      name: ${svcName}
      macos_instance:
        # can be a remote or a local virtual machine
        image: ghcr.io/cirruslabs/macos-monterey-base:latest
      hello_script:
        - export TOKEN_FILE="$PWD/tokenFile"
        - bash ./script-guest.sh

  '';

in {
  script = ''
    set -x

    # make cirrus and tart available via PATH
    export PATH="$PATH:/opt/homebrew/bin"

    # clean the working directory
    chmod +w -R ./cirrusWorkDir || true
    rm -rf ./cirrusWorkDir

    # populate the working directory
    mkdir ./cirrusWorkDir
    cat ${cirrucConf} > ./cirrusWorkDir/.cirrus.yml
    cp ${scriptGuest} ./cirrusWorkDir/script-guest.sh
    cp ${runnerTarball}/tarball/github-runner.tar.xz ./cirrusWorkDir/github-runner.tar.xz
    cp ${cfg.tokenFile} ./cirrusWorkDir/tokenFile

    # run the VM (the current dir will be pushed inside the VM)
    cd ./cirrusWorkDir
    cirrus run -o simple
  '';

  path = config.environment.systemPackages;

  environment =
    {
      NIX_SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      RUNNER_ROOT = stateDir;
      USER = "github-runner";
      HOME = baseDir;
    }
    // cfg.extraEnvironment;

  serviceConfig.UserName = "github-runner";
  serviceConfig.GroupName = "github-runner";
  serviceConfig.WorkingDirectory = baseDir;

  serviceConfig.KeepAlive = true;
  serviceConfig.RunAtLoad = true;
  serviceConfig.ThrottleInterval = 30;
  serviceConfig.ProcessType = "Interactive";
  serviceConfig.StandardErrorPath = "${baseDir}/runner-logs";
  serviceConfig.StandardOutPath = "${baseDir}/runner-logs";
  serviceConfig.WatchPaths = [
    cfg.tokenFile
    "/etc/resolv.conf"
    "/Library/Preferences/SystemConfiguration/NetworkInterfaces.plist"
  ];
}
