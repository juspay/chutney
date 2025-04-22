# A guide to resize the EC2 instance

- Save the postgres database dump:
  ```sh
  ssh root@<public-ip>
  # FIXME: Do we have to take the data dump of `seaql_migrations` table? Can it be excluded?
  sudo -u atticd pg_dump -d atticd --data-only > atticd_data_only_dump.sql
  exit
  sftp root@<public-ip>
  get atticd_data_only_dump.sql
  ```
- Modify `resource.aws_instance.chutney.instance_type` in `./modules/terranix/default.nix` to the desired size of the instance.
- `just apply` (Assumes AWS credentials are configured, see [Getting Started](/README.md#getting-started)
- Copy the new host key:
  ```sh
  ssh root@<public-ip>
  # Copy the output of
  cat /etc/ssh/ssh_host_ed25519_key.pub
  ```
- Modify chutney's public IP in `./secrets/secrets.nix`
- Run `just secrets-rekey`
- Run `nixos-rebuild switch --flake .#chutney --target-host root@<public-ip>` to activate chutney's nixosConfiguration.
- Load the postgres database dump:
  ```sh
  sftp root@<public-ip>
  put atticd_data_only_dump.sql
  exit
  ssh root@<public-ip>
  cat atticd_data_only_dump.sql | sudo -u atticd psql -d atticd
  ```

