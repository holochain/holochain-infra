package main

import (
	"fmt"
	"os"

	"github.com/pulumi/pulumi-random/sdk/v4/go/random"
	"github.com/pulumi/pulumi/sdk/v3/go/pulumi"
	"github.com/threefoldtech/pulumi-threefold/sdk/go/threefold"
	"github.com/threefoldtech/pulumi-threefold/sdk/go/threefold/provider"
)

func main() {
	pulumi.Run(func(ctx *pulumi.Context) error {
		mnemonic := os.Getenv("TF_VAR_tfgrid_dev_mnemonics")

		grid_provider, err := threefold.NewProvider(ctx, "grid provider", &threefold.ProviderArgs{
			Mnemonic: pulumi.String(mnemonic),
			Network:  pulumi.String("dev"),
		})
		if err != nil {
			return err
		}

		const node int = 195

		mycelium_seed, err := random.NewRandomBytes(ctx, "mycelium_seed", &random.RandomBytesArgs{
			Length: pulumi.Int(32),
		})
		if err != nil {
			return err
		}

		mycelium_ip_seed, err := random.NewRandomBytes(ctx, "mycelium_ip_seed", &random.RandomBytesArgs{
			Length: pulumi.Int(6),
		})
		if err != nil {
			return err
		}

		grid_network, err := provider.NewNetwork(ctx, "network0", &provider.NetworkArgs{
			Description: pulumi.String("example grid network 0"),
			Ip_range:    pulumi.String("10.1.0.0/16"),
			Name:        pulumi.String("network0"),
			Nodes:       pulumi.Array{pulumi.Int(node)},

			Mycelium_keys: pulumi.StringMap{fmt.Sprint(node): mycelium_seed.Hex},
		},
			pulumi.Provider(grid_provider),
		)
		if err != nil {
			return err
		}

		deployment, err := provider.NewDeployment(ctx, "deployment", &provider.DeploymentArgs{
			// Disks            provider.DiskArrayInput
			// Name              pulumi.StringInput
			// Network_name      pulumi.StringPtrInput
			// Node_id           pulumi.Input
			// Qsfs              QSFSInputArrayInput
			// Solution_provider pulumi.IntPtrInput
			// Solution_type     pulumi.StringPtrInput
			// Vms               VMInputArrayInput
			// Zdbs              ZDBInputArrayInput

			Name:         pulumi.String("steveej_vm0"),
			Node_id:      pulumi.Int(node),
			Network_name: grid_network.Name,
			Vms: provider.VMInputArray{provider.VMInputArgs{
				Cpu:         pulumi.Int(1),
				Description: pulumi.String("description"),
				Entrypoint:  pulumi.String("/init"),

				Env_vars: pulumi.StringMap{
					"SSH_KEY": pulumi.String("ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDAIODJoJ7Chi8jPTGmKQ5MlB7+TgNGznreeRW/K34v1ey23/FlnIxP9XyyLkzojKALTfAQYgqzrQV3HDSRwhd1rXB7YLq1/CiVWRJvDMTkJiOCV515eiUJGXu1G8e12d/USPNBMEzMJGvqBCIGYen5OxXkyIHIREfePNi5k337G5z9fiuiggxJl9ty6qZ4XIRgFQj9jAoShixP/+99I7XrGWeFQ1BmLZWzi20SQGKvogYnOszDZFqBAHGFnCFYHaTz2jOXXCtQsa27gr8D2iLRFaxvhB7XMK+VbpDcZGjmfRJ701XxFv15GFnFAV71hTaYqj/Ebpw9Vs02+gUp3+tt cardno:17_673_080"),
				},

				Flist:        pulumi.String("https://sj-bm-hostkey0.dev.infra.holochain.org/s3/tfgrid-eval/tfgrid-base.20240408.190655.fl"),
				Memory:       pulumi.Int(512),
				Name:         pulumi.String("steveej_vm0"),
				Network_name: grid_network.Name,

				// Planetary      pulumi.BoolPtrInput     `pulumi:"planetary"`
				// Public_ip      pulumi.BoolPtrInput     `pulumi:"public_ip"`
				// Public_ip6     pulumi.BoolPtrInput     `pulumi:"public_ip6"`
				Rootfs_size: pulumi.Int(10000),
				// Zlogs          ZlogArrayInput          `pulumi:"zlogs"`

				Mycelium_ip_seed: mycelium_ip_seed.Hex,
			}},
		},
			pulumi.Provider(grid_provider),
		)
		if err != nil {
			return err
		}

		// pulumi.All(grid_network, deployment).ApplyT(
		// 	func(args []interface{}) pulumi.StringOutput {
		// 		return pulumi.Sprintf("network: %s\n, deployment: %s", args[0], args[1])
		// 	},
		// )

		/*
			can be accessed via:
			pulumi stack -s dev output mycelium_ip
		*/
		ctx.Export("mycelium_ip", deployment.Vms_computed.Index(pulumi.Int(0)).Mycelium_ip())
		ctx.Export("vm0", deployment.Vms_computed.Index(pulumi.Int(0)))

		return nil
	})
}
