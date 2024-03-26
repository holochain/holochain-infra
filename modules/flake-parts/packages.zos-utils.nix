{
  # System independent arguments.
  ...
}: {
  perSystem = {
    # Arguments specific to the `perSystem` context.
    pkgs,
    inputs',
    ...
  }: {
    packages = let
      configName = "tfgrid-base";
    in
      {
        zos-vm-build = pkgs.writeShellApplication {
          name = "zos-vm-build";
          text = ''
            set -xueE -o pipefail

            ts="''${1:-"$(date +"%Y%m%d.%H%M%S")"}"

            resultName="${configName}.$ts"

            mkdir -p results

            nix build --out-link results/"$resultName" \
              .\#nixosConfigurations."${configName}".config.system.build.zosVmDir
            ln -sf --no-target-directory "$resultName" results/"${configName}.latest"

            echo results/"$resultName"
          '';
        };

        # TODO: automate proper minio hosting. this is exemplary only and requires imperative setup of minio
        zos-vm-serve-s3 = pkgs.writeShellApplication {
          name = "zos-vm-serve-s3";
          runtimeInputs = [
            pkgs.minio
          ];
          text = ''
            set -ueE -o pipefail

            cd .minio

            env \
              MINIO_ROOT_USER=minioadmin \
              MINIO_ROOT_PASSWORD="$(cat minioadmin.key)" \
              minio server --console-address ":9001" storage
          '';
        };

        zos-vm-publish-s3 = let
          s3BaseUrl = "sj-bm-hostkey0.dev.infra.holochain.org";
          s3ListenUrl = "${s3BaseUrl}:9000";
          s3HttpUrl = "https://${s3BaseUrl}/s3";
          s3Bucket = "tfgrid-eval";
        in
          pkgs.writeShellApplication {
            name = "zos-vm-publish-s3";
            runtimeInputs = [
              pkgs.minio-client
            ];
            text = ''
              set -xueE -o pipefail

              rootfsRel="$1"
              rootfsBase="$(basename "$rootfsRel")"
              rootfsDir="$(dirname "$rootfsRel")"
              rootfs="$(realpath "$rootfsRel")"

              workDir="$rootfsDir"/"$rootfsBase".work

              mkdir -p "$workDir"
              cd "$workDir"

              # mc rm --recursive --force localhost/${s3Bucket} || echo removal failed
              env RUST_MIN_STACK=8388608 \
                rfs pack -m result.fl -s s3://minioadmin:"$(cat ../../.minio/minioadmin.key)"@${s3ListenUrl}/${s3Bucket}\?region=us-east-1 "$rootfs/" | tee rfs-pack.log

              # TODO: document or automate setting up the alias "localhost"
              mc cp result.fl localhost/${s3Bucket}/"$rootfsBase".fl
              echo ${s3HttpUrl}/${s3Bucket}/"$rootfsBase".fl > public-url

              touch published

              echo "$workDir"/result.fl
            '';
          };
      }
      // (
        let
          macaddr = "12:34:56:78:90:ab";
          userData = pkgs.writeText "user-data" ''
            #cloud-config

            ssh_pwauth: True
          '';
          metaData = pkgs.writeText "meta-data" ''
            instance-id: tfgrid
            local-hostname: tfgrid
          '';
          networkConfig = pkgs.writeText "network-config" ''
            version: 2
            ethernets:
              id0:
                match:
                  macaddress: '${macaddr}'
                dhcp4: false
                addresses: [192.168.249.2/24]
                gateway4: 192.168.249.1
          '';
          # see https://github.com/cloud-hypervisor/cloud-hypervisor/blob/main/scripts/create-cloud-init.sh
          cloudinitImg =
            pkgs.runCommand "cloudinit.img"
            {
              nativeBuildInputs = [pkgs.dosfstools pkgs.mtools];
            } ''
              mkdosfs -n CIDATA -C "$out" 8192

              # TODO: clarify whether the name needs to match
              cp ${userData} user-data
              mcopy -oi "$out" -s user-data ::

              cp ${metaData} meta-data
              mcopy -oi "$out" -s meta-data ::

              cp ${networkConfig} network-config
              mcopy -oi "$out" -s network-config ::
            '';
        in {
          zos-vm-boot-local = pkgs.writeShellApplication {
            # see https://gist.github.com/muhamadazmy/a10bfb0cc77084c9b09dea5e49ec528e
            name = "zos-vm-boot-local";
            runtimeInputs = [
              pkgs.virtiofsd
              pkgs.cloud-hypervisor
            ];
            text = ''
              set -xeuE -o pipefail

              # path to root directory
              rootfs="''${1}"
              kernel="$rootfs/boot/vmlinuz"
              initram="$rootfs/boot/initrd.img"

              workDir="$rootfs.work"
              mkdir -p "$workDir"

              socket="$workDir/virtiofs.sock"

              fail() {
                  echo "$1" >&2
                  exit 1
              }

              if [ ! -f "$kernel" ]; then
                  fail "kernel file not found"
              fi

              if [ ! -f "$initram" ]; then
                  fail "kernel file not found"
              fi

              # start virtiofsd in the background
              sudo virtiofsd -d --socket-path="$socket" --shared-dir="$rootfs/" &>/dev/null &
              fspid="$!"

              sleep 1

              cleanup() {
                (
                  set +eEu

                  sudo kill "$fspid"
                  rm -rf "$socket"
                )
              }

              trap cleanup EXIT

              sudo cloud-hypervisor \
                  --memory size=2048M,shared=on \
                  --disk path=${cloudinitImg},readonly=true \
                  --net "tap=,mac=${macaddr},ip=,mask=" \
                  --kernel "$kernel" \
                  --initramfs "$initram" \
                  --fs tag=vroot,socket="$socket" \
                  --cmdline "rw console=ttyS0 boot.shell_on_fail" \
                  --serial tty \
                  --console off
            '';

            # --cmdline "rw console=ttyS0 init=$init boot.shell_on_fail boot.debug1mounts" \
          };
          zos-vm-boot-s3 = pkgs.writeShellApplication {
            # see https://gist.github.com/muhamadazmy/a10bfb0cc77084c9b09dea5e49ec528e
            name = "zos-vm-boot-s3";
            runtimeInputs = [
              pkgs.virtiofsd
              pkgs.cloud-hypervisor
              inputs'.threefold-rfs.packages.default
            ];
            text = ''
              set -xeuE -o pipefail

              # path to root directory
              rootfs="''${1}"
              kernel="$rootfs/boot/vmlinuz"
              initram="$rootfs/boot/initrd.img"

              workDir="$rootfs.work"
              mountDir="$workDir/mnt"
              mkdir -p "$mountDir"

              socket="$workDir/virtiofs.sock"

              fail() {
                  echo "$1" >&2
                  exit 1
              }

              rfs mount -m "$workDir"/result.fl "$mountDir" > "$workDir"/rfs_mount.log 2>&1 &
              mountpid="$!"

              sleep 3

              if [ ! -f "$kernel" ]; then
                  fail "kernel file not found"
              fi

              if [ ! -f "$initram" ]; then
                  fail "kernel file not found"
              fi

              # start virtiofsd in the background
              sudo virtiofsd -d --socket-path="$socket" --shared-dir="$mountDir" &>/dev/null &
              fspid="$!"

              cleanup() {
                (
                  set +eEu

                  sudo kill "$fspid"
                  rm -rf "$socket"

                  kill "$mountpid"
                  umount --lazy "$mountDir"
                  rmdir "$mountDir"
                )
              }

              trap cleanup EXIT

              sudo cloud-hypervisor \
                  --memory size=2048M,shared=on \
                  --disk path=${cloudinitImg},readonly=true \
                  --net "tap=,mac=${macaddr},ip=,mask=" \
                  --kernel "$kernel" \
                  --initramfs "$initram" \
                  --fs tag=vroot,socket="$socket" \
                  --cmdline "rw console=ttyS0 boot.shell_on_fail" \
                  --serial tty \
                  --console off
            '';

            # --cmdline "rw console=ttyS0 init=$init boot.shell_on_fail boot.debug1mounts" \
          };
        }
      );
  };
}
