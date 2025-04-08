{ flake, config, lib, ... }:
let
  inherit (flake) inputs;
  # Credit: https://github.com/input-output-hk/cardano-monitoring/blob/065c923c1fb54f8bb6056ded67c4273a7f58c8d9/flake/opentofu/cluster.nix#L32-L39
  mkSecurityGroupRule = lib.recursiveUpdate {
    protocol = "tcp";
    cidr_blocks = [ "0.0.0.0/0" ];
    ipv6_cidr_blocks = [ "::/0" ];
    prefix_list_ids = [ ];
    security_groups = [ ];
    self = true;
  };
  node = inputs.self.nixosConfigurations.chutney;
in
{

  provider.aws.region = "ap-south-1";

  resource.aws_vpc.chutney.cidr_block = "10.0.0.0/16";
  resource.aws_internet_gateway.chutney.vpc_id = "\${aws_vpc.chutney.id}";
  resource.aws_route_table.chutney.vpc_id = "\${aws_vpc.chutney.id}";
  resource.aws_route.ipv4 = {
    route_table_id = "\${aws_route_table.chutney.id}";
    destination_cidr_block = "0.0.0.0/0";
    gateway_id = "\${aws_internet_gateway.chutney.id}";
  };
  resource.aws_subnet.chutney = {
    vpc_id = "\${aws_vpc.chutney.id}";
    cidr_block = "10.0.1.0/24";
  };
  resource.aws_route_table_association.chutney_route = {
    subnet_id = "\${aws_subnet.chutney.id}";
    route_table_id = "\${aws_route_table.chutney.id}";
  };
  resource.aws_security_group.allow_web_and_ssh = {
    vpc_id = "\${aws_vpc.chutney.id}";
    ingress = map mkSecurityGroupRule [
      {
        description = "Allow HTTP";
        from_port = 80;
        to_port = 80;
      }
      {
        description = "Allow HTTPS";
        from_port = 443;
        to_port = 443;
      }
      {
        description = "Allow SSH";
        from_port = 22;
        to_port = 22;
      }
    ];

    egress = map mkSecurityGroupRule [
      {
        description = "Allow outbound traffic";
        from_port = 0;
        to_port = 0;
        protocol = "-1";
      }
    ];
  };

  resource.aws_key_pair.deployer = {
    key_name = "deployer-pub-key";
    public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFN5Ov2zDIG59/DaYKjT0sMWIY15er1DZCT9SIak07vK";
  };

  # Credit: https://nixos.github.io/amis/
  data.aws_ami.nixos_arm64 = {
    owners = [ "427812963091" ];
    most_recent = true;

    filter = [
      {
        name = "name";
        values = [ "nixos/${node.config.system.nixos.release}*" ];
      }
      {
        name = "architecture";
        values = [ "arm64" ];
      }
    ];
  };

  # Create VPS (EC2 instance)
  resource.aws_instance.chutney = {
    ami = "\${data.aws_ami.nixos_arm64.id}";
    instance_type = "t4g.micro";
    vpc_security_group_ids = [ "\${aws_security_group.allow_web_and_ssh.id}" ];
    subnet_id = "\${aws_subnet.chutney.id}";
    key_name = config.resource.aws_key_pair.deployer.key_name;
    iam_instance_profile = "\${aws_iam_instance_profile.chutney_profile.id}";
    associate_public_ip_address = true;
    root_block_device = {
      volume_size = 50; # In GB
      volume_type = "gp3";
      iops = 3000;
    };

    tags = {
      Name = "chutney-attic-server";
    };
  };

  # Storage backend
  resource.aws_s3_bucket.chutney_attic_cache = {
    bucket = "chutney-attic-cache";
    # Destroy bucket despite it being non-empty
    force_destroy = true;
    tags = {
      Name = "chutney-attic-cache";
    };
  };

  resource.aws_iam_instance_profile.chutney_profile = {
    role = "\${aws_iam_role.chutney_ec2_role.name}";
  };

  resource.aws_iam_role.chutney_ec2_role = {
    name = "chutney-ec2-role";
    assume_role_policy = builtins.toJSON {
      Version = "2012-10-17";
      Statement = [
        {
          Action = "sts:AssumeRole";
          Effect = "Allow";
          Principal.Service = "ec2.amazonaws.com";
        }
      ];
    };
  };

  resource.aws_s3_bucket_policy.allow_chutney = {
    bucket = "\${aws_s3_bucket.chutney_attic_cache.id}";
    policy = "\${data.aws_iam_policy_document.allow_chutney.json}";
  };

  data.aws_iam_policy_document.allow_chutney = {
    statement = {
      principals = {
        type = "AWS";
        identifiers = [ "\${aws_iam_role.chutney_ec2_role.arn}" ];
      };

      actions = [ "s3:GetObject" "s3:PutObject" "s3:DeleteObject" "s3:ListBucket" ];

      resources = [
        "\${aws_s3_bucket.chutney_attic_cache.arn}"
        "\${aws_s3_bucket.chutney_attic_cache.arn}/*"
      ];
    };
  };

  output."chutney_public_ip".value = "\${aws_instance.chutney.public_ip}";
}
