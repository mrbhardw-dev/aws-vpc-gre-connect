

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

module "nva_vpc" {
  count                                = var.enable_stack ? 1 : 0
  source                               = "aws-ia/vpc/aws"
  version                              = "4.4.4"
  name                                 = "${module.label.id}-connect-vpc-01"
  cidr_block                           = local.nva_vpc_cidr
  vpc_assign_generated_ipv6_cidr_block = true
  az_count                             = 2
  transit_gateway_id                   = module.tgw[0].ec2_transit_gateway_id
  tags                                 = module.label.tags_aws
  transit_gateway_routes = {
    public = "192.168.0.0/24"
  }

  subnets = {
    public = {
      name_prefix               = "${module.label.id}-connect-sbt-public"
      netmask                   = 24
      nat_gateway_configuration = "all_azs"
    }
    private = {
      name_prefix             = "${module.label.id}-connect-sbt-private"
      netmask                 = 24
      connect_to_public_natgw = true
    }

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
  vpc_flow_logs = {
    name_override        = "${module.label.id}-connect"
    log_destination_type = "cloud-watch-logs"
    retention_in_days    = 180
  }
}


module "spoke_vpc" {
  count                                = var.enable_stack ? 1 : 0
  source                               = "aws-ia/vpc/aws"
  version                              = "4.4.4"
  name                                 = "${module.label.id}-spoke-vpc-01"
  cidr_block                           = local.spoke_vpc_cidr
  vpc_assign_generated_ipv6_cidr_block = true
  az_count                             = 2
  transit_gateway_id                   = module.tgw[0].ec2_transit_gateway_id
  tags                                 = module.label.tags_aws
  transit_gateway_routes = {
    private = "0.0.0.0/0"
  }

  subnets = {
    private = {
      name_prefix             = "${module.label.id}-spoke-sbt-private"
      netmask                 = 24
      connect_to_public_natgw = false
    }

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
  vpc_flow_logs = {
    name_override        = "${module.label.id}-spoke"
    log_destination_type = "cloud-watch-logs"
    retention_in_days    = 180
  }
}

# module "route_server" {
#   source = "./modules/route-server"

#   enabled                   = var.enable_stack
#   name_prefix               = "${module.label.id}-route-server"
#   tags                      = module.label.tags_aws
#   vpc_id                    = module.nva_vpc[0].vpc_attributes.id
#   amazon_side_asn           = 64512
#   persist_routes            = "disable"
#   sns_notifications_enabled = false

#   endpoints = [
#     {
#       name_suffix = "primary"
#       subnet_id   = element(local.public_subnet_ids, 0)
#     },
#     {
#       name_suffix = "secondary"
#       subnet_id   = element(local.public_subnet_ids, 1)
#     }
#   ]
#   peers = {
#     "01" = {
#       endpoint_key = "primary"
#       peer_ip      = module.ec2_instance[0].private_ip
#     },
#     "02" = {
#       endpoint_key = "secondary"
#       peer_ip      = module.ec2_instance[1].private_ip
#     }
#   }
#   bgp_local_as = 65001

#   propagation_route_table_ids = local.transit_gateway_subnet_rt_map

# }
