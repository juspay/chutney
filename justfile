# Default command when 'just' is run without arguments
default:
  @just --list

# Edit a secret file
secret-edit:
    cd ./secrets && agenix -e $(fd -e age | fzf)

# Rekey all secrets (usually done after adding/removing hosts/users)
secrets-rekey:
    cd ./secrets && agenix -r

# Get the public IP of the server (Assumes `apply` has been run)
[group('utils')]
get-ip:
  terraform output -raw chutney_public_ip

