# chutney

> [!WARNING]
> **Status: 🚧 Work in Progress 🚧**
>
> This project might undergo changes as we scale the cache to cover 1000+ users at Juspay.
>
> See https://github.com/juspay/chutney/issues/17 for current status on reliability.

`chutney` provides a NixOS + [terranix](https://terranix.org/) configuration to deploy a reliable Nix binary cache server, powered by [attic](https://docs.attic.rs/).

- [Getting Started](#getting-started)
- [Limitations](#limitations)
- [Operational Decisions](#operational-decisions)
- [Guide](#guide)
  - [Cache Creation](#create-cache)
  - [Secrets](#secrets)
  - [Garbage Collection](#garbage-collection)
  - [Migration](/docs/MIGRATION.md)
- [Gotchas](#gotchas)
- [Discussion](#discussion)

## Getting Started

By default, chutney deploys its infrastructure on AWS. To get started, follow the [AWS guide](/docs/AWS.md).

If you are not using AWS, you can use the standalone NixOS modules, which are decoupled from the terranix configuration. See the [NixOS Modules guide](/docs/NIXOS_MODULES.md).

## Limitations

- [Unbounded DB and S3 growth](https://github.com/juspay/chutney/issues/52)

## Operational Decisions

### Disable Chunking

Chunking saves storage space but costs significantly more due to S3 PUT request pricing. Disabling chunking **saves ~95% on S3 PUT cost** (see https://github.com/juspay/chutney/issues/48#issuecomment-3478249583). One might argue that the storage cost might bite us in the long run, but we don't have to worry about that given we solve https://github.com/juspay/chutney/issues/52.

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

### Flaky `destroy`

`destroy` script can indefinitely keep trying to delete the `aws_vpc.chutney`, this happens (atleast with Juspay's AWS account) when the vpc has a non-default security group depenedency not managed by terraform. This dependency has to be manually deleted by running `nix run .#vpc-sg-cleanup <vpc-id>` in another terminal window.

### HTTP 524

If your domain uses cloudflare and the requests are proxied through cloudflare, `attic push` might fail on large Nix store objects with`HTTP 524`. This is owing to [cloudflare's 100 second timeout](https://developers.cloudflare.com/support/troubleshooting/http-status-codes/cloudflare-5xx-errors/#error-524-a-timeout-occurred). You can fix this by changing `Proxy status` for your domain from `Proxied` to `DNS only` in the cloudflare dashboard, as the aforementioned page describes:

> If you regularly run HTTP requests that take over 100 seconds to complete (for example, large data exports), move those processes behind a subdomain not proxied (grey clouded) in the Cloudflare DNS app.

## Discussion

To discuss this project, post in [GitHub Discussions](https://github.com/juspay/chutney/discussions) or join the [NixOS Asia community](https://nixos.asia/en/#community).
