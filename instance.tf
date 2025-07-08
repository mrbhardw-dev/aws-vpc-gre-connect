################################################################################
# Local Variables for EC2 Instance Configuration
################################################################################

locals {
  instance_count     = var.enable_stack ? 2 : 0
  base_name          = "${module.label.id}-frr-instance"
  base_iam_role_name = "${module.label.id}-frr-iam-role"

  # BGP configuration for each FRR instance
  # Instance 1: Primary NVA in AZ-a
  # Instance 2: Secondary NVA in AZ-b
  bgp_configs = [
    {
      # BGP ASN Configuration
      local_as      = 65001  # Local ASN for NVA instances
      tgw_remote_as = 64532  # Transit Gateway ASN
      router_id     = "100.64.2.100"  # BGP Router ID (same as private IP)
      
      # BGP Neighbors
      ibgp_neighbour               = "169.254.6.2"    # iBGP peer (other NVA)
      tgw_connect_ebgp_neighbour_1 = "169.254.200.2"  # Primary TGW Connect peer
      tgw_connect_ebgp_neighbour_2 = "169.254.200.3"  # Secondary TGW Connect peer
      
      # Route Advertisement
      bgp_advertised_network = "172.16.0.10/32"  # Loopback network to advertise
      primary_route_map      = "PREFER_MED_10"    # Route map for path preference
      secondary_route_map    = "PREFER_MED_20"    # Route map for backup path

      # iBGP GRE Tunnel Configuration (between NVAs)
      ibgp_gre_local_ip  = "100.64.2.100"     # Local IP for GRE tunnel
      ibgp_gre_remote_ip = "100.64.3.100"     # Remote IP for GRE tunnel
      ibgp_gre_inside_ip = "169.254.6.1/29"   # Inside IP for GRE tunnel

      # TGW Connect GRE Tunnel Configuration
      ebgp_gre_local_ip  = "100.64.2.100"      # Local IP for TGW GRE tunnel
      ebgp_gre_remote_ip = "192.168.0.10"      # TGW Connect peer IP
      ebgp_gre_inside_ip = "169.254.200.1/29"  # Inside IP for TGW GRE tunnel

      # Loopback Interface Configuration
      loopback_ip = "172.16.0.10"  # Loopback IP address
      LO_IF       = "lo:1"         # Loopback interface name
    },
    {
      # BGP ASN Configuration
      local_as      = 65001  # Local ASN for NVA instances
      tgw_remote_as = 64532  # Transit Gateway ASN
      router_id     = "100.64.3.100"  # BGP Router ID (same as private IP)
      
      # BGP Neighbors
      ibgp_neighbour               = "169.254.6.1"    # iBGP peer (other NVA)
      tgw_connect_ebgp_neighbour_1 = "169.254.201.2"  # Primary TGW Connect peer
      tgw_connect_ebgp_neighbour_2 = "169.254.201.3"  # Secondary TGW Connect peer
      
      # Route Advertisement
      bgp_advertised_network = "172.16.0.11/32"  # Loopback network to advertise
      primary_route_map      = "PREFER_MED_10"    # Route map for path preference
      secondary_route_map    = "PREFER_MED_20"    # Route map for backup path

      # iBGP GRE Tunnel Configuration (between NVAs)
      ibgp_gre_local_ip  = "100.64.3.100"     # Local IP for GRE tunnel
      ibgp_gre_remote_ip = "100.64.2.100"     # Remote IP for GRE tunnel
      ibgp_gre_inside_ip = "169.254.6.2/29"   # Inside IP for GRE tunnel

      # TGW Connect GRE Tunnel Configuration
      ebgp_gre_local_ip  = "100.64.3.100"      # Local IP for TGW GRE tunnel
      ebgp_gre_remote_ip = "192.168.0.11"      # TGW Connect peer IP
      ebgp_gre_inside_ip = "169.254.201.1/29"  # Inside IP for TGW GRE tunnel

      # Loopback Interface Configuration
      loopback_ip = "172.16.0.11"  # Loopback IP address
      LO_IF       = "lo:1"         # Loopback interface name
    }
  ]

  # Instance configuration mapping
  # Creates configuration for each NVA instance with specific AZ and subnet placement
  instance_configs = [
    for i in range(local.instance_count) : {
      name              = "${local.base_name}-${format("%02d", i + 1)}"
      iam_role_name     = "${local.base_iam_role_name}-${format("%02d", i + 1)}"
      availability_zone = element(local.azs, i)
      subnet_id         = element(local.public_subnet_ids, i)
      private_ip        = i == 0 ? "100.64.2.100" : "100.64.3.100"  # Static IPs for consistent BGP peering
      bgp_config        = local.bgp_configs[i]
    }
  ]
}

################################################################################
# User Data Generation
################################################################################

# Generate user data scripts for each FRR instance
# These scripts configure BGP, GRE tunnels, and loopback interfaces
resource "local_file" "user_data" {
  count    = local.instance_count
  content  = templatefile("${path.module}/templates/bgp_config.sh.tpl", local.instance_configs[count.index].bgp_config)
  filename = "${path.module}/rendered/user_data_${count.index}.sh"
}

################################################################################
# FRR Network Virtual Appliance Instances
################################################################################

# Deploy FRR instances for BGP routing and GRE tunneling
# These instances act as Network Virtual Appliances (NVAs)
module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.8.0"
  count   = local.instance_count
  
  # Instance Configuration
  name                        = local.instance_configs[count.index].name
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = "mrbhardw"  # TODO: Make this configurable
  availability_zone           = local.instance_configs[count.index].availability_zone
  subnet_id                   = local.instance_configs[count.index].subnet_id
  private_ip                  = local.instance_configs[count.index].private_ip
  source_dest_check           = false  # Required for routing functionality
  vpc_security_group_ids      = [module.security_group_nva[0].security_group_id]
  
  # Network Configuration
  create_eip    = true   # Assign Elastic IP for internet access
  disable_api_stop = false
  
  # IAM Configuration
  create_iam_instance_profile = true
  iam_role_name               = local.instance_configs[count.index].iam_role_name
  iam_role_use_name_prefix    = false
  iam_role_description        = "IAM role for FRR NVA instance"
  iam_role_policies = {
    AdministratorAccess = "arn:aws:iam::aws:policy/AdministratorAccess"  # TODO: Use least privilege
  }

  # User Data Configuration
  user_data_base64            = base64encode(local_file.user_data[count.index].content)
  user_data_replace_on_change = true

  # CPU Configuration for network performance
  cpu_options = {
    core_count       = 2
    threads_per_core = 1
  }

  # Storage Configuration
  enable_volume_tags = false
  root_block_device = [{
    encrypted   = true
    volume_type = "gp3"
    throughput  = 200
    volume_size = 50
    tags = {
      Name = "root"
    }
  }]

  ebs_block_device = [{
    device_name = "/dev/sdf"
    volume_type = "gp3"
    volume_size = 5
    throughput  = 200
    tags = {
      MountPoint = "/mnt/data"
    }
  }]

  tags = module.label.tags_aws
}


################################################################################
# Spoke VPC Test Instance
################################################################################

# Test instance in spoke VPC to demonstrate connectivity through Transit Gateway
# This instance represents a typical workload that routes through the NVAs
module "ec2_instance_spoke" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.8.0"
  
  # Instance Configuration
  name              = "${module.label.id}-spoke-instance"
  ami               = data.aws_ami.ubuntu.id
  instance_type     = var.instance_type
  key_name          = "mrbhardw"  # TODO: Make this configurable
  availability_zone = element(local.azs, 0)
  subnet_id         = element(local.spoke_private_subnet_ids, 0)
  vpc_security_group_ids = [module.security_group_spoke[0].security_group_id]
  
  # Network Configuration
  create_eip       = false  # No internet access needed for test instance
  disable_api_stop = false
  
  # IAM Configuration
  create_iam_instance_profile = true
  iam_role_name               = "${module.label.id}-spoke-iam-role-01"
  iam_role_use_name_prefix    = false
  iam_role_description        = "IAM role for spoke test instance"
  iam_role_policies = {
    AdministratorAccess = "arn:aws:iam::aws:policy/AdministratorAccess"  # TODO: Use least privilege
  }

  # CPU Configuration
  cpu_options = {
    core_count       = 2
    threads_per_core = 1
  }

  # Storage Configuration
  enable_volume_tags = false
  root_block_device = [{
    encrypted   = true
    volume_type = "gp3"
    throughput  = 200
    volume_size = 50
    tags = {
      Name = "root"
    }
  }]

  ebs_block_device = [{
    device_name = "/dev/sdf"
    volume_type = "gp3"
    volume_size = 5
    throughput  = 200
    tags = {
      MountPoint = "/mnt/data"
    }
  }]

  tags = module.label.tags_aws
}
