################################################################################
# Managed Prefix List
################################################################################

# Create a managed prefix list for common CIDR blocks
# This allows centralized management of IP ranges across security groups
resource "aws_ec2_managed_prefix_list" "prefix_list" {
  count          = var.enable_stack ? 1 : 0
  name           = "${module.label.id}-prefix-list-01"
  address_family = "IPv4"
  max_entries    = 5
  tags           = module.label.tags_aws
  
  dynamic "entry" {
    for_each = var.prefixes
    content {
      cidr        = entry.value
      description = entry.key
    }
  }
}

################################################################################
# NVA VPC - Network Virtual Appliance VPC
################################################################################

# VPC that hosts the FRR instances for BGP routing and GRE tunneling
# This VPC connects to Transit Gateway and provides routing services
module "nva_vpc" {
  count   = var.enable_stack ? 1 : 0
  source  = "aws-ia/vpc/aws"
  version = "4.4.4"
  
  name                                 = "${module.label.id}-connect-vpc-01"
  cidr_block                           = local.nva_vpc_cidr
  vpc_assign_generated_ipv6_cidr_block = true
  az_count                             = 2
  transit_gateway_id                   = module.tgw[0].ec2_transit_gateway_id
  tags                                 = module.label.tags_aws
  
  # Route Transit Gateway traffic through public subnets
  transit_gateway_routes = {
    public = "192.168.0.0/24"
  }

  subnets = {
    # Public subnets for FRR instances with internet access
    public = {
      name_prefix               = "${module.label.id}-connect-sbt-public"
      netmask                   = 24
      nat_gateway_configuration = "all_azs"
    }
    
    # Private subnets for internal resources
    private = {
      name_prefix             = "${module.label.id}-connect-sbt-private"
      netmask                 = 24
      connect_to_public_natgw = true
    }

    # Transit Gateway subnets for TGW attachment
    transit_gateway = {
      name_prefix                                     = "${module.label.id}-connect-sbt-tgw"
      netmask                                         = 28
      assign_ipv6_cidr                                = true
      connect_to_public_natgw                         = true
      transit_gateway_default_route_table_association = false
      transit_gateway_default_route_table_propagation = false
      transit_gateway_appliance_mode_support          = "enable"
      transit_gateway_dns_support                     = "disable"
      tags = {
        subnet_type = "tgw"
      }
    }
  }
  
  # Enable VPC Flow Logs for network monitoring
  vpc_flow_logs = {
    name_override        = "${module.label.id}-connect"
    log_destination_type = "cloud-watch-logs"
    retention_in_days    = 180
  }
}


################################################################################
# Spoke VPC - Demonstration VPC
################################################################################

# Spoke VPC demonstrates connectivity through Transit Gateway
# This represents a typical workload VPC that routes through the NVA
module "spoke_vpc" {
  count   = var.enable_stack ? 1 : 0
  source  = "aws-ia/vpc/aws"
  version = "4.4.4"
  
  name                                 = "${module.label.id}-spoke-vpc-01"
  cidr_block                           = local.spoke_vpc_cidr
  vpc_assign_generated_ipv6_cidr_block = true
  az_count                             = 2
  transit_gateway_id                   = module.tgw[0].ec2_transit_gateway_id
  tags                                 = module.label.tags_aws
  
  # Route all traffic through Transit Gateway
  transit_gateway_routes = {
    private = "0.0.0.0/0"
  }

  subnets = {
    # Private subnets for workload instances
    private = {
      name_prefix             = "${module.label.id}-spoke-sbt-private"
      netmask                 = 24
      connect_to_public_natgw = false
    }

    # Transit Gateway subnets for TGW attachment
    transit_gateway = {
      name_prefix                                     = "${module.label.id}-spoke-sbt-tgw"
      netmask                                         = 28
      transit_gateway_default_route_table_association = false
      transit_gateway_default_route_table_propagation = false
      transit_gateway_appliance_mode_support          = "enable"
      transit_gateway_dns_support                     = "disable"
      tags = {
        subnet_type = "tgw"
      }
    }
  }
  
  # Enable VPC Flow Logs for network monitoring
  vpc_flow_logs = {
    name_override        = "${module.label.id}-spoke"
    log_destination_type = "cloud-watch-logs"
    retention_in_days    = 180
  }
}


