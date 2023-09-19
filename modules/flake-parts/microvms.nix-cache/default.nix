{
  self,
  inputs,
  ...
}: let
  name = "vm-nixcache";
in {
  flake.nixosConfigurations.${name} = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      ./configuration.nix

      # Include the microvm module
      inputs.microvm.nixosModules.microvm
      # Add more modules here
      ({
        config,
        lib,
        pkgs,
        ...
      }: {
        microvm.mem = 4096;
        microvm.vcpu = 2;

        microvm.interfaces = [
          {
            id = "${name}";
            type = "user";

            # Ethernet address of the MicroVM's interface, not the host's
            #
            # Locally administered have one of 2/6/A/E in the second nibble.
            mac = "02:00:00:00:00:01";
          }
        ];
        microvm.hypervisor = "qemu";
        microvm.forwardPorts = [
          # forward local port 2222 -> 22, to ssh into the VM
          {
            from = "host";
            host.port = 2222;
            guest.port = 22;
          }

          {
            from = "host";
            host.port = 5000;
            guest.port = 5000;
          }
        ];

        microvm.writableStoreOverlay = "/nix/.rw-store";
        microvm.volumes = [
          # {
          #   image = "swap.img";
          #   mountPoint = "/var/swap";
          #   size = 1024 * 8;
          # }
          {
            image = ".storage/nix-store-overlay.img";
            mountPoint = config.microvm.writableStoreOverlay;
            size = 1024 * 100;
            fsType = "ext4";
          }
        ];

        # swapDevices = [
        #   {
        #     device = "/var/swap/main";
        #     size = (builtins.elemAt config.microvm.volumes 0).size - 1;
        #   }
        # ];
      })
    ];
    # system = "x86_64-linux";
    specialArgs = self.specialArgs // {inherit name;};
  };
}
