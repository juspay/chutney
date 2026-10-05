# Default command when 'just' is run without arguments
default:
  @just --list

aws_profile := "nix"
aws_config := justfile_directory() + "/.aws/config"

aws-login:
    @mkdir -p "$(dirname "{{aws_config}}")"
    @test -s "{{aws_config}}" || { tmp="$(mktemp "{{aws_config}}.tmp.XXXXXX")"; if (cd secrets && agenix -d aws/config.age -i ~/.ssh/id_ed25519) > "$tmp"; then mv "$tmp" "{{aws_config}}"; else rm -f "$tmp"; exit 1; fi; }
    @chmod 600 "{{aws_config}}"
    AWS_CONFIG_FILE="{{aws_config}}" AWS_PROFILE={{aws_profile}} aws sts get-caller-identity >/dev/null 2>&1 \
    && echo "Already logged in." \
    || AWS_CONFIG_FILE="{{aws_config}}" AWS_PROFILE={{aws_profile}} aws sso login --sso-session juspay

[private]
check-aws:
    @AWS_CONFIG_FILE={{aws_config}} AWS_PROFILE={{aws_profile}} aws sts get-caller-identity >/dev/null 2>&1 || { echo "error: no AWS access. Run 'just aws-login' and retry." >&2; exit 1; }

# Edit a secret file
secret-edit:
    cd ./secrets && agenix -e $(fd -e age | fzf)

# Rekey all secrets (usually done after adding/removing hosts/users)
secrets-rekey:
    cd ./secrets && agenix -r

# Get the public IP of the server (Assumes `apply` has been run)
[group('utils')]
get-ip:
  AWS_CONFIG_FILE={{aws_config}} AWS_PROFILE={{aws_profile}} terraform output -raw chutney_public_ip

# Apply the Terraform infrastructure.
[group('deploy')]
deploy-tf: check-aws
    AWS_CONFIG_FILE={{aws_config}} AWS_PROFILE={{aws_profile}} nix run .#apply

# Create the versioned Terraform state bucket (one-time setup).
[group('deploy')]
create-state-bucket: check-aws
    AWS_CONFIG_FILE={{aws_config}} AWS_PROFILE={{aws_profile}} nix run .#create-state-bucket

# Build and activate NixOS on the server; nothing is built locally.
[group('deploy')]
deploy-nixos:
    nixos-rebuild switch --fast --flake .#chutney \
        --target-host root@13.200.148.146 \
        --build-host root@13.200.148.146

# Terraform first, then NixOS.
[group('deploy')]
deploy-all: deploy-tf deploy-nixos
