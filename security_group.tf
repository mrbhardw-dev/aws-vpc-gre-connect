################################################################################
# Security Groups
################################################################################

# Security group for NVA instances running FRR
# Allows BGP traffic, GRE tunnels, and management access
module "security_group_nva" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.3.0"
  count   = var.enable_stack ? 1 : 0
  
  name            = "${module.label.id}-connect-sg-01"
  use_name_prefix = false
  description     = "Security group for FRR NVA instances"
  vpc_id          = module.nva_vpc[0].vpc_attributes.id
  
  # Ingress Rules
  ingress_with_cidr_blocks = [
    # SSH access from specific management IPs
    {
      rule        = "ssh-tcp"
      cidr_blocks = "54.240.197.224/32"  # Management IP 1
    },
    {
      rule        = "ssh-tcp"
      cidr_blocks = "37.228.200.130/32"  # Management IP 2
    },
    # Allow all traffic from spoke VPC
    {
      rule        = "all-all"
      cidr_blocks = local.spoke_vpc_cidr
    },
    # Allow all traffic from Transit Gateway CIDR
    {
      rule        = "all-all"
      cidr_blocks = "192.168.0.0/24"
    }
  ]

  # Egress Rules - Allow all outbound traffic
  egress_with_cidr_blocks = [
    {
      rule        = "all-all"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
}

# Security group for spoke VPC test instances
# Allows connectivity testing through Transit Gateway
module "security_group_spoke" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.3.0"
  count   = var.enable_stack ? 1 : 0
  
  name            = "${module.label.id}-spoke-sg-01"
  use_name_prefix = false
  description     = "Security group for spoke VPC test instances"
  vpc_id          = module.spoke_vpc[0].vpc_attributes.id
  
  # Ingress Rules
  ingress_with_cidr_blocks = [
    # Allow traffic from loopback networks (advertised by NVAs)
    {
      rule        = "all-all"
      cidr_blocks = "172.16.0.0/24"
    },
    # Allow traffic from spoke VPC (internal communication)
    {
      rule        = "all-all"
      cidr_blocks = local.spoke_vpc_cidr
    },
    # Allow traffic from NVA VPC
    {
      rule        = "all-all"
      cidr_blocks = local.nva_vpc_cidr
    }
  ]

  # Egress Rules - Allow all outbound traffic
  egress_with_cidr_blocks = [
    {
      rule        = "all-all"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
}