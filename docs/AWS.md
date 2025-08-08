# Getting started with attic on AWS

1. Configure AWS credentials
    1. Login to your [AWS console](https://aws.amazon.com/console/)
    1. Select "Access keys" under your preferred account and use one of the specified methods to "Get credentials"
1. Run `nix run .#create-state-bucket` to store the [terraform state file](https://developer.hashicorp.com/terraform/language/state)
1. Replace `resource.aws_key_pair.deployer.public_key` in `./modules/terranix/default.nix` with your SSH public key
1. Run `apply` to deploy the server and its support infra
1. Run `just get-ip` to fetch the server's public IPv4 address
1. Replace public keys in `./secrets/secrets.nix` with your own. 
1. Delete the existing `./secrets/attic/env.age`, [generate](https://docs.attic.rs/admin-guide/deployment/nixos.html#generating-the-credentials-file) new secret and add it by following [Secrets](#secrets)
1. Run `nixos-rebuild switch --flake .#chutney --target-host root@<public-ip> --accept-flake-config` to activate `chutney`'s nixosConfiguration.
1. Generate all-access root token (to be used by admins):
    ```sh
    ssh root@<public-ip>
    atticd-atticadm make-token --sub 'e2e-root' --validity '2y' --push '*' --pull '*' --delete '*' --create-cache '*' --destroy-cache '*' --configure-cache '*' --configure-cache-retention '*'
    ```
1. Delete the existing `./secrets/attic/root-token.age` and follow [Secrets](#secrets) to add the token generated before
1. Follow [Administrate cache](#administrate-cache) to manage the cache using `attic-client`
1. Follow [cache creation](https://docs.attic.rs/tutorial.html#cache-creation) guide from attic.
1. Follow the guide from attic to [push](https://docs.attic.rs/tutorial.html#pushing) and [pull](https://docs.attic.rs/tutorial.html#pulling) to/from the cache.

