# A script to delete AWS EC2 security groups not managed by terraform
{
  perSystem = { pkgs, ... }: {
    apps.vpc-sg-cleanup = {
      type = "app";
      program = pkgs.writeShellApplication {
        name = "vpc-sg-cleanup";
        runtimeInputs = [ pkgs.awscli2 ];
        text = ''
          SG_IDS=$(aws ec2 describe-security-groups \
            --filters "Name=vpc-id,Values=$1" \
            --region ap-south-1 \
            --query "SecurityGroups[?GroupName!='default'].GroupId" \
            --output text)
          for SG_ID in $SG_IDS; do
            echo "Deleting security group: $SG_ID"
            aws ec2 delete-security-group --group-id "$SG_ID" --region "ap-south-1"
          done
        '';
        meta.description = ''
          Manually delete the non-default security-group from a given VPC.

          `terraform destroy` only deletes the SG's managed by it. There can be other non-default SG's without
          deleting which the VPC will not be destroyed.
        '';
      };
    };
  };
}
