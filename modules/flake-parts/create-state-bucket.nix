# A script that creates a versioned S3 bucket for terraform to store state in
{ inputs, ... }:
{
  perSystem = { pkgs, config, system, ... }: {
    # Based on https://gitlab.com/initech-project/main-codebase/-/blob/main/lib/terranix/default.nix?ref_type=heads#L98-128
    apps.create-state-bucket = {
      type = "app";
      program = pkgs.writeShellApplication {
        name = "create-state-bucket";
        runtimeInputs = [ pkgs.awscli2 ];
        runtimeEnv =
          let
            # TODO: Export the `terranixConfigurationAst` in `config.terranix.terranixConfigurations.default.result`
            terranix-cfg = (inputs.terranix.lib.terranixConfigurationAst {
              inherit system;
              modules = [ ../../modules/terranix ];
            }).config;
          in
          {
            BUCKET_NAME = terranix-cfg.terraform.backend.s3.bucket;
            AWS_REGION = terranix-cfg.provider.aws.region;
          };
        text = ''
          echo "Creating S3 bucket $BUCKET_NAME in region $AWS_REGION..."

          aws s3api create-bucket \
            --bucket "$BUCKET_NAME" \
            --region "$AWS_REGION" \
            --create-bucket-configuration LocationConstraint="$AWS_REGION"

          echo "Enabling versioning on the bucket $BUCKET_NAME..."
          aws s3api put-bucket-versioning \
            --bucket "$BUCKET_NAME" \
            --versioning-configuration Status=Enabled

          echo "Setting default encryption on the bucket $BUCKET_NAME..."
          aws s3api put-bucket-encryption \
            --bucket "$BUCKET_NAME" \
            --server-side-encryption-configuration '{
              "Rules": [{
                "ApplyServerSideEncryptionByDefault": {
                  "SSEAlgorithm": "AES256"
                }
              }]
            }'

          echo "Bucket $BUCKET_NAME setup is complete."
        '';
      };
    };
  };
}
