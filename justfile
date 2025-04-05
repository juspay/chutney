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

# Destroy the infrastructure and remove its state
destroy-all:
  just init
  terraform destroy
  rm terraform.tfstate*

# Generates `config.tf.json` and runs `terraform init`
[group('utils')]
init:
  nix build -o config.tf.json
  terraform init

# Get the public IP of the server (Assumes `just apply` has been run)
[group('utils')]
get-ip:
  terraform output -raw chutney_public_ip

