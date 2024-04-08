variable "tfgrid_dev_mnemonics" {
    sensitive = true
}

variable "nixos_flake" {
  type = string
  default = "github:holochain/holochain-infra/workorch-zos#tfgrid-devnet-vm0"
}

variable "build_host" {
  type = string
  default = "root@sj-bm-hostkey0.dev.infra.holochain.org"
}

terraform {
  required_providers {
    grid = {
      source = "threefoldtech/grid"
      version = "1.10.0-dev"
    }

    sops = {
      source = "carlpett/sops"
      version = "~> 0.5"
    }
  }
}

data "sops_file" "static-age-keys" {
  source_file = "../secrets/static-age-keys.yaml"
}

provider "grid" {
  mnemonics = var.tfgrid_dev_mnemonics
  network   = "dev" # or test to use testnet
}

locals {
  vm0_name= "steveej_vm0"
  node = 195
}

resource "random_bytes" "mycelium_ip_seed" {
  length = 6
}

resource "random_bytes" "mycelium_key" {
  length = 32
}

resource "grid_network" "net0" {
  name        = local.vm0_name
  nodes       = [local.node]
  ip_range    = "10.1.0.0/16"

  mycelium_keys = {
    format("%s", local.node) = random_bytes.mycelium_key.hex
  }
  description = "newer network"

  add_wg_access = true
}
resource "grid_deployment" "d1" {
  node         = local.node
  network_name = grid_network.net0.name
  #   disks {
  #     name        = "store"
  #     size        = 50
  #     description = "volume holding store data"
  #   }

  vms {
    name  = local.vm0_name
    # flist = "https://sj-bm-hostkey0.dev.infra.holochain.org/s3/tfgrid-eval/tfgrid-devnet-vm0.20240406.103712.fl"
    flist = "https://sj-bm-hostkey0.dev.infra.holochain.org/s3/tfgrid-eval/tfgrid-base.20240408.190655.fl"

    cpu   = 8
    # publicip   = true
    memory     = 4096
    rootfs_size = 20000 # MiB
    entrypoint = "/init"
    # mounts {
    #   disk_name   = "store"
    #   mount_point = "/nix"
    # }

    mycelium_ip_seed = random_bytes.mycelium_ip_seed.hex

    env_vars = {
      SSH_KEY = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDAIODJoJ7Chi8jPTGmKQ5MlB7+TgNGznreeRW/K34v1ey23/FlnIxP9XyyLkzojKALTfAQYgqzrQV3HDSRwhd1rXB7YLq1/CiVWRJvDMTkJiOCV515eiUJGXu1G8e12d/USPNBMEzMJGvqBCIGYen5OxXkyIHIREfePNi5k337G5z9fiuiggxJl9ty6qZ4XIRgFQj9jAoShixP/+99I7XrGWeFQ1BmLZWzi20SQGKvogYnOszDZFqBAHGFnCFYHaTz2jOXXCtQsa27gr8D2iLRFaxvhB7XMK+VbpDcZGjmfRJ701XxFv15GFnFAV71hTaYqj/Ebpw9Vs02+gUp3+tt cardno:17_673_080"
      DEPLOYMENT = "tofu"
    }
  }

  connection {
    type     = "ssh"
    user     = "root"
    agent    = true
    host     = grid_deployment.d1.vms[0].mycelium_ip
  }

  provisioner "remote-exec" {
    inline = [
      "set -eEux -o pipefail",

      # TODO: consider generating a new key, adding it to sops, and re-encrypting the secrets
      "printf '' > /etc/age.key",
      "chmod 400 /etc/age.key",
      "echo '${data.sops_file.static-age-keys.data["tfgrid-shared"]}' >> /etc/age.key",
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "set -eEux -o pipefail",

      # switch to a deployment specific profile
      # can use build-host only if the local agent has access to it
      "export NIX_SSHOPTS='-o StrictHostKeyChecking=accept-new'",
      # "systemctl restart dbus",
      # "nixos-rebuild -v --build-host ${var.build_host} --flake ${var.nixos_flake} switch"
    ]
  }

  # TODO: figure out how to avoid evaluating on the target system.
  # ssh root@sj-bm-hostkey0.dev.infra.holochain.org "nix build --print-out-paths --no-link -vL github:holochain/holochain-infra/workorch-zos#nixosConfigurations.tfgrid-devnet-vm0.config.system.build.toplevel"

}

output "vm0_wg_config" {
  value = grid_network.net0.access_wg_config
}

output "vm0_zmachine1_ip" {
  value = grid_deployment.d1.vms[0].ip
}

# output "vm0_computed_public_ip" {
#   value = split("/", grid_deployment.d1.vms[0].computedip)[0]
# }

output "vm0_mycelium_ip" {
  value = grid_deployment.d1.vms[0].mycelium_ip
}

output "vm0_console_url" {
  value = grid_deployment.d1.vms[0].console_url
}
