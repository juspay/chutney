{ flake, config, lib, ... }:
let
  inherit (flake) inputs;
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
  resource.aws_route_table_association.chutney_route =  {
    subnet_id = "\${aws_subnet.chutney.id}";
    route_table_id = "\${aws_route_table.chutney_vpc_rt.id}";
  };
  resource.aws_security_group.chutney_ssh = {
    name = "allow ssh";
    vpc_id = "\${aws_vpc.chutney.id}";
    ingress = [
      { protocol = "tcp";
        from_port = 22;
        to_port = 22;
        cidr_blocks = [ "0.0.0.0/0" ];

        # required attributes; `terraform plan` fails without them
        description = "";
        ipv6_cidr_blocks = [];
        prefix_list_ids = [];
        security_groups = [];
        self = false;
      }
    ];
    egress = [
      { protocol = "tcp";
        from_port = 0;
        to_port = 65535;
        cidr_blocks = [ "0.0.0.0/0" ];

        # required attributes; `terraform plan` fails without them
        description = "";
        ipv6_cidr_blocks = [];
        prefix_list_ids = [];
        security_groups = [];
        self = false;
      }
    ];
  };

  # provide ssh key
  resource.aws_key_pair.deployer = {
    key_name = "deployer-pub-key";
    public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOZaSBdDB7D4ceQgghss2xrI7MEwFyN2tRMkgkUTBOg8";
  };

  # create machine
  resource.aws_instance.chutney = {
    # Picked the nixos/24.11 arm64 instance from https://nixos.github.io/amis/ after selecting "ap-south-1" region in the first column.
    # TODO: automatate (see https://github.com/terranix/terranix-examples/blob/921680efb8af0f332d8ad73718d53907f9483e24/aws-nixos-server/config.nix#L23)
    ami = "ami-093e0b67d6bb0bfae";
    instance_type = "t4g.micro";
    vpc_security_group_ids = [ "\${aws_security_group.chutney_ssh.id}" ];
    subnet_id = "\${aws_subnet.chutney.id}";
    associate_public_ip_address = true;
    key_name = config.resource.aws_key_pair.deployer.key_name;

    tags = {
      Name = "chutney-attic-server";
      terranix = "true";
      Terraform = "true";
    };
  };
  
  # Create S3 bucket used for both uploading custom AMI and as storage backend for the cache
  # resource.aws_s3_bucket."chutney" = {
  #   bucket = "chutney-tf-prod-${config.provider.aws.region}"; 
  #   tags = {
  #     Name = "chutney-tf-prod-${config.provider.aws.region}";
  #     Environment = "prod";
  #   };
  # };

}
