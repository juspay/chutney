# Default command when 'just' is run without arguments
default:
  @just --list


# View the deployment plan
plan:
  just init
  terraform plan

# Deploy the infrastructure
apply:
  just init
  terraform apply

# Destroy the infrastructure (state bucket, configured in `terranixConfiguration.backend.s3.bucket` will not be destroyed)
destroy:
  just init
  terraform destroy

# Edit a secret file
secret-edit:
    cd ./secrets && agenix -e $(fd -e age | fzf)

# Rekey all secrets (usually done after adding/removing hosts/users)
secrets-rekey:
    cd ./secrets && agenix -r

# Generates `config.tf.json` and runs `terraform init`
[group('utils')]
init:
  nix build -o config.tf.json
  terraform init

# Get the public IP of the server (Assumes `just apply` has been run)
[group('utils')]
get-ip:
  terraform output -raw chutney_public_ip

