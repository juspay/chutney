# A script that creates a versioned S3 bucket for terraform to store state in
{
  perSystem = { pkgs, ... }: {
    # Based on https://gitlab.com/initech-project/main-codebase/-/blob/main/lib/terranix/default.nix?ref_type=heads#L98-128
    apps.create-state-bucket = {
      type = "app";
      program = pkgs.writeShellApplication {
        name = "create-state-bucket";
        runtimeInputs = [ pkgs.awscli2 ];
        runtimeEnv = {
          # TODO: autowire from terranix configuration
          BUCKET_NAME = "chutney-tf-state-1";
          AWS_REGION = "ap-south-1";
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
