# chutney

`chutney` is a [terranix](https://terranix.org/) module to deploy production-ready [attic](https://docs.attic.rs/) binary cache for Nix store objects in AWS.

## Usage

1. Configure AWS credentials
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

## Garbage collection (GC)

Auto GC is disabled in chutney. Manually run the GC in the `atticd` server:

```sh
sudo -u atticd attic-gc-once
```

