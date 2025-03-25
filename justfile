# Default command when 'just' is run without arguments
default:
  @just --list

# Generates `config.tf.json` and runs `terraform init`
init:
  nix build -o config.tf.json
  terraform init

# Run `just init` and `terraform plan`
plan:
  just init
  terraform plan

# Run `just init` and `terraform apply` (deploy)
apply:
  just init
  terraform apply

# Get the public IP of the EC2 (Assumes `just apply` has been run)
get-ip:
  terraform output -raw chutney_public_ip

# Run `terraform destroy` and delete `terraform.tfstate*`
destroy:
  just init
  terraform destroy
  rm terraform.tfstate*
  
