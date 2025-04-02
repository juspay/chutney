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
  resource.aws_internet_gateway.chutney_gw.vpc_id = "\${aws_vpc.chutney.id}";
  resource.aws_route_table.chutney_vpc_rt.vpc_id = "\${aws_vpc.chutney.id}";
  resource.aws_route.ipv4 = {
    route_table_id = "\${aws_route_table.chutney_vpc_rt.id}";
    destination_cidr_block = "0.0.0.0/0";
    gateway_id = "\${aws_internet_gateway.chutney_gw.id}";
  };
  resource.aws_subnet.chutney = {
    vpc_id = "\${aws_vpc.chutney.id}";
    cidr_block = "10.0.1.0/24";
  };
  resource.aws_route_table_association.chutney_route = {
    subnet_id = "\${aws_subnet.chutney.id}";
    route_table_id = "\${aws_route_table.chutney_vpc_rt.id}";
  };
  resource.aws_security_group.chutney_ssh = {
    name = "allow ssh";
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

  # provide ssh key
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
        values = [ "nixos/${node.config.system.stateVersion}*" ];
      }
      {
        name = "architecture";
        values = [ "arm64" ];
      }
    ];
  };

  # create machine
  resource.aws_instance.chutney = {
    ami = "\${data.aws_ami.nixos_arm64.id}";
    instance_type = "t4g.micro";
    vpc_security_group_ids = [ "\${aws_security_group.chutney_ssh.id}" ];
    subnet_id = "\${aws_subnet.chutney.id}";
    key_name = config.resource.aws_key_pair.deployer.key_name;
    iam_instance_profile = "\${aws_iam_instance_profile.chutney_profile.id}";
    root_block_device = {
      volume_size = 50; # In GB
      volume_type = "gp3";
      iops = 3000;
      delete_on_termination = true;
    };

    # Configure options for IMDS
    metadata_options = {
      http_put_response_hop_limit = 5;
      # attic, at the time of testing, wasn't working with IMDSv2
      http_tokens = "optional"; # Allow both IMDSv1 and IMDSv2
    };

    tags = {
      Name = "chutney-attic-server";
      terranix = "true";
      Terraform = "true";
    };
  };


  # Generate a public IP
  #
  # Note: We aren't using `associate_public_ip_address = true;` in `aws_instance` because that will generate a new
  # IP when a new instance is created.
  resource.aws_eip."chutney_ip" = { };

  # Associate the IP with the instance.
  #
  # Note: `resource.aws_eip` can mention `instance` in its configuration to associate to, but
  # that would mean eip will be destroyed along with the instance.
  resource.aws_eip_association."chutney_ip_assoc" = {
    instance_id   = "\${aws_instance.chutney.id}";
    allocation_id = "\${aws_eip.chutney_ip.id}";
  };

  # Create S3 bucket used for both uploading custom AMI and as storage backend for the cache
  resource.aws_s3_bucket."chutney" = {
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
    bucket = "\${aws_s3_bucket.chutney.id}";
    policy = "\${data.aws_iam_policy_document.allow_chutney.json}";
  };

  data.aws_iam_policy_document.allow_chutney = {
    statement = {
      principals = {
        type = "AWS";
        identifiers = [ "\${aws_iam_role.chutney_ec2_role.arn}" ];
      };

      actions = [ "s3:*" ];

      resources = [
        "\${aws_s3_bucket.chutney.arn}"
        "\${aws_s3_bucket.chutney.arn}/*"
      ];
    };
  };


  output."chutney_public_ip".value = "\${aws_eip.chutney_ip.public_ip}";


}
