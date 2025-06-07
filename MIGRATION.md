> [!IMPORTANT]
> This guide is for migrating from one AWS account to another in the same region, but most parts will be same while migrating to a different region and some while migrating to a different cloud provider.

> [!NOTE]
> Throughout this guide, from here on, we will refer to "AWS account" as "account".

- Rename `backend.s3.bucket` and `resource.aws_s3_bucket.chutney_attic_cache.bucket` in terranix config, to not conflict with existing buckets in the same region.
  - We went with `chutney-tf-state-1` and `chutney-attic-cache-1` respectively.
- Replace `services.atticd.settings.storage.bucket`, in attic's nixosModule, to match `resource.aws_s3_bucket.chutney_attic_cache.bucket` (Note: This step will be redundant once `services.atticd.settings.storage.bucket` is autowired from the terranix config)
- Replace `flake.outputs.apps.create-state-bucket.program.runtimeEnv.BUCKET_NAME` to match `backend.s3.bucket`. (Note: This step, like the previous one will also be redundant after autowiring)
- `rm -rf .terraform` to remove the old cached state.
- Follow [Getting Started](/README.md#getting-started) from Step 1 to 6 on the new account.
- `ssh-keyscan <new-public-ip>` and use the output to replace `chutney` public key in [Secrets](/secrets/secrets.nix)
- `just secrets-rekey`
- Run `nixos-rebuild switch --flake .#chutney --target-host root@<new-public-ip>` to activate `chutney`'s nixosConfiguration.
  - Note: `acme` service will fail to start here as the `A` record for the domain isn't flipped yet.
- Stop requests to the attic server in the old account by setting `services.nginx.enable = false` (Note: Make all the changes to the old account in a new worktree without the changes from above to avoid mix-ups)
- Add rules for the s3 bucket in old account to give read access to the one in new account:
  ```nix
  # Inside terranix config
  {
    data.aws_iam_policy_document.allow_chutney = {
      statement = [
        {
          # principals = { ... };
        }
        {
          principals = {
            type = "AWS";
            identifiers = [ "arn:aws:iam::<new-account-id>:root"];
          };
  
          actions = [ "s3:GetObject" "s3:ListBucket" ];
  
          resources = [
            "\${aws_s3_bucket.chutney_attic_cache.arn}"
            "\${aws_s3_bucket.chutney_attic_cache.arn}/*"
          ];
        }
      ];
    };
  }
  ```
- With AWS Credentials configured for new account, run: `aws s3 sync s3://chutney-attic-cache s3://chutney-attic-cache-1 --source-region ap-south-1 --region ap-south-1` (Note: This process was extremely slow for me, taking over ~3hours for source bucket size between 8-9GB)
- Save the postgres database dump:
  ```sh
  ssh root@<old-public-ip>
  # FIXME: Do we have to take the data dump of `seaql_migrations` table? Can it be excluded?
  sudo -u atticd pg_dump -d atticd --data-only > atticd_data_only_dump.sql
  exit
  sftp root@<old-public-ip>
  get atticd_data_only_dump.sql
  ```
  (235MB database dump, can be more or less depending on the bucket size during migration)
- Load the postgres database dump in the server of the new account:
  ```sh
  sftp root@<new-public-ip>
  put atticd_data_only_dump.sql
  exit
  ssh root@<new-public-ip>
  cat atticd_data_only_dump.sql | sudo -u atticd psql -d atticd
  ```
  It took me under a minute to load the database dump, might take longer. You might also see this error:
  ```
  ERROR:  duplicate key value violates unique constraint "seaql_migrations_pkey"
  DETAIL:  Key (version)=(m20221227_000001_create_cache_table) already exists.
  CONTEXT:  COPY seaql_migrations, line 1
  ```
  I ignored it as it caused no problem during [Resizing](/RESIZING.md), feel free to investigate further.
- Update `remote_file` location and `remote_file_id` of each chunk in the postgres database:
  ```psql
  sudo -u atticd psql -d atticd
  UPDATE chunk
  SET
      remote_file = jsonb_set(
          remote_file::jsonb,
          '{S3,bucket}',
          '"chutney-attic-cache-1"'::jsonb,
          false -- 'false' means create_missing; since 'bucket' should exist, we don't need to create it.
      )::text,
      remote_file_id = REPLACE(remote_file_id, 'chutney-attic-cache', 'chutney-attic-cache-1')
  WHERE
      remote_file::jsonb @> '{"S3": {"bucket": "chutney-attic-cache"}}'
      OR remote_file_id LIKE '%/chutney-attic-cache/%';
  ```
  Note: Without this step, you will be able to push and pull new chunks but fail to pull old chunks if the new instance doesn't have access to old bucket.
- Flip the `A` record on your domain to the new IP
- Run `nixos-rebuild switch --flake .#chutney --target-host root@<new-public-ip>` to renew SSL certs.

