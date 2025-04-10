# chutney

`chutney` is a [terranix](https://terranix.org/) module to deploy production-ready [attic](https://docs.attic.rs/) binary cache for Nix store objects in AWS.

- [Getting Started](#getting-started)
- [Guide](#guide)
  - [Create cache](#create-cache)
  - [Secrets](#secrets)
  - [Garbage Collection](#garbage-collection)
- [Gotchas](#gotchas)

## Getting Started

1. Configure AWS credentials
1. Run `nix run .#create-state-bucket` to store the [terraform state file](https://developer.hashicorp.com/terraform/language/state)
1. Replace `resource.aws_key_pair.deployer.public_key` in `./modules/terranix/default.nix` with your SSH public key
1. Run `just apply` to deploy the server and its support infra
1. Run `just get-ip` to fetch the server's public IPv4 address
1. Run `nixos-rebuild switch --flake .#chutney --target-host root@<public-ip>` to activate `chutney`'s nixosConfiguration.
1. Generate all-access root token (to be used by admins):
    ```sh
    ssh root@<public-ip>
    atticd-atticadm make-token --sub 'e2e-root' --validity '2y' --push '*' --pull '*' --delete '*' --create-cache '*' --destroy-cache '*' --configure-cache '*' --configure-cache-retention '*'
    ```
1. Run `nix run nixpkgs#attic-client login root http://<public-ip> <token-from-previous-command>` to administrate the cache.
1. Follow [cache creation](https://docs.attic.rs/tutorial.html#cache-creation) guide from attic.
1. Follow the guide from attic to [push](https://docs.attic.rs/tutorial.html#pushing) and [pull](https://docs.attic.rs/tutorial.html#pulling) to/from the cache.

## Guide

### Administrate cache

Login to attic using the root-token for admin related work:
```
cd secrets && nix run nixpkgs#attic-client -- login root http://13.202.152.28 $(agenix -d attic/root-token.age)
```

### Create cache

- Ensure you are logged in as an admin (see [Administrate cache](#administrate-cache))
- Run `nix run nixpkgs#attic-client cache create <cache-name>`
- SSH into the host and generate the access token, see comments above `attic/oss-push-token.age` in `secrets/secrets.nix`. Also see <https://docs.attic.rs/tutorial.html#access-control>

### Secrets

`chutney` uses [agenix](https://github.com/ryantm/agenix) for secrets management.

#### Adding a new secret

Run `cd secrets && agenix -e <mysecret.age>`

#### Editing an existing secret

Run `just secret-edit` and select the key to edit.

#### Adding a new user/host

Add the new user/host in `./secrets/secrets.nix` and run `just secrets-rekey` to allow the new user/host to decrypt the keys.

### Garbage Collection

> **Note:**
> Auto GC is disabled in `chutney`. The only way GC will free up space is if you have configured `retention-period` for your cache. See <https://docs.attic.rs/tutorial.html#garbage-collection>

Run Garbage Collection once:
```sh
ssh root@<public-ip>
sudo -u atticd attic-gc-once
```

### Support more platforms in `.terraform.lock.hcl`

Currently only `darwin_arm64` is supported. To manage infra from other platform/s, follow:
- `mv .terraform.lock.hcl .terraform.lock.hcl.bkp`
- `terraform init`
- Add back the extra `hashes` from `.terraform.lock.hcl.bkp` to `.terraform.lock.hcl`

We can't use the `terraform providers lock -platform=<platform-1> -platform=<platform-2> ...` as this command always fetches and locks the latest aws provider and not the pinned one from nixpkgs (The provider is pinned using `terraform.withPlugins` in `devShells.default` ).

## Gotchas

### Flaky `just destroy-all`

`just destory-all` can indefinitely keep trying to delete the `aws_vpc.chutney`, this happens (atleast with Juspay's AWS account) when the vpc has a non-default security group depenedency not managed by terraform. This dependency has to be manually deleted by running `nix run .#vpc-sg-cleanup <vpc-id>` in another terminal window.

