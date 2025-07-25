# chutney

> [!NOTE]
> **Status: 🚧 Work in Progress 🚧**
>
> This project might undergo changes as we adopt the cache server in more projects.

`chutney` is a [terranix](https://terranix.org/) module to deploy production-ready [attic](https://docs.attic.rs/) binary cache for Nix store objects in AWS.

- [Getting Started](#getting-started)
- [Guide](#guide)
  - [Create cache](#create-cache)
  - [Secrets](#secrets)
  - [Garbage Collection](#garbage-collection)
  - [Migration](/MIGRATION.md)
- [Gotchas](#gotchas)

## Getting Started

1. Configure AWS credentials
    1. Login to your [AWS console](https://aws.amazon.com/console/)
    1. Select "Access keys" under your preferred account and use one of the specified methods to "Get credentials"
1. Run `nix run .#create-state-bucket` to store the [terraform state file](https://developer.hashicorp.com/terraform/language/state)
1. Replace `resource.aws_key_pair.deployer.public_key` in `./modules/terranix/default.nix` with your SSH public key
1. Run `just apply` to deploy the server and its support infra
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

## Guide

### Administrate cache

Login to attic using the root-token for admin related work:
```
cd secrets && nix run nixpkgs#attic-client -- login root https://cache.nixos.asia $(agenix -d attic/root-token.age)
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

> [!NOTE]
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

### HTTP 524

If your domain uses cloudflare and the requests are proxied through cloudflare, `attic push` might fail on large Nix store objects with`HTTP 524`. This is owing to [cloudflare's 100 second timeout](https://developers.cloudflare.com/support/troubleshooting/http-status-codes/cloudflare-5xx-errors/#error-524-a-timeout-occurred). You can fix this by changing `Proxy status` for your domain from `Proxied` to `DNS only` in the cloudflare dashboard, as the aforementioned page describes:

> If you regularly run HTTP requests that take over 100 seconds to complete (for example, large data exports), move those processes behind a subdomain not proxied (grey clouded) in the Cloudflare DNS app.
