# Getting started with attic on AWS

Run all commands from the repository's development shell:

```sh
nix develop
```

1. When deploying in Juspay's environment, connect to the GlobalProtect VPN.
1. Run `just aws-login` to authenticate with AWS SSO.
1. Run `just create-state-bucket` once to create the versioned S3 bucket that stores the [Terraform state file](https://developer.hashicorp.com/terraform/language/state).
1. Replace `resource.aws_key_pair.deployer.public_key` in `./modules/terranix/default.nix` with your SSH public key
1. Run `just deploy-tf` to deploy the server and its supporting infrastructure.
1. Run `just get-ip` to fetch the server's public IPv4 address
1. If the address differs from the one in the `deploy-nixos` recipe, update its `--target-host` and `--build-host` values.
1. Replace public keys in `./secrets/secrets.nix` with your own. 
1. Delete the existing `./secrets/attic/env.age`, [generate](https://docs.attic.rs/admin-guide/deployment/nixos.html#generating-the-credentials-file) new secret and add it by following [Secrets](#secrets)
1. Run `just deploy-nixos` to build and activate the NixOS configuration on the remote server.
1. Generate all-access root token (to be used by admins):
    ```sh
    ssh root@<public-ip>
    atticd-atticadm make-token --sub 'e2e-root' --validity '2y' --push '*' --pull '*' --delete '*' --create-cache '*' --destroy-cache '*' --configure-cache '*' --configure-cache-retention '*'
    ```
1. Delete the existing `./secrets/attic/root-token.age` and follow [Secrets](#secrets) to add the token generated before
1. Follow [Administrate cache](../README.md#administrate-cache) to manage the cache using `attic-client`
1. Follow [cache creation](https://docs.attic.rs/tutorial.html#cache-creation) guide from attic.
1. Follow the guide from attic to [push](https://docs.attic.rs/tutorial.html#pushing) and [pull](https://docs.attic.rs/tutorial.html#pulling) to/from the cache.
