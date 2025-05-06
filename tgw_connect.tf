################################################################################
# Transit Gateway
################################################################################

module "tgw" {
  source  = "terraform-aws-modules/transit-gateway/aws"
  version = "2.13.0"
  count   = var.enable_stack ? 1 : 0

  name                        = "${module.label.id}-connect-tgw-01"
  description                 = "TGW shared across AWS accounts"
  amazon_side_asn             = 64532
  transit_gateway_cidr_blocks = local.transit_gateway_cidr_block

  enable_auto_accept_shared_attachments = true
  enable_sg_referencing_support         = true
  enable_multicast_support              = false
  ram_allow_external_principals         = true
  ram_principals                        = ["058264222681"]

  tgw_default_route_table_tags = { Name = "tgw-rt-default" }
  tgw_route_table_tags         = { Name = "tgw-rt-connect" }
  tags                         = module.label.tags_aws
}

################################################################################
# Transit Gateway Connect
################################################################################

resource "aws_ec2_transit_gateway_connect" "this" {
  count = var.enable_stack ? 1 : 0

  transit_gateway_id                              = module.tgw[0].ec2_transit_gateway_id
  transport_attachment_id                         = module.nva_vpc[0].transit_gateway_attachment_id
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = merge(
    { Name = "${module.label.id}-connect-01_connect_attachement" },
    module.label.tags_aws
  )
}

resource "aws_ec2_transit_gateway_connect_peer" "this" {
  count = var.enable_stack ? 2 : 0

  inside_cidr_blocks            = [var.connect_peer_cidr_blocks[count.index]]
  peer_address                  = module.ec2_instance[count.index].private_ip
  transit_gateway_address       = var.transit_gateway_address[count.index]
  transit_gateway_attachment_id = aws_ec2_transit_gateway_connect.this[0].id
  bgp_asn                       = "65001"

  tags = merge(
    { Name = "${module.label.id}-peer-tgw-connect-${format("%02d", count.index)}" },
    module.label.tags_aws
  )
}

################################################################################
# Route Tables
################################################################################

resource "aws_ec2_transit_gateway_route_table" "spoke" {
  transit_gateway_id = module.tgw[0].ec2_transit_gateway_id

  tags = { Name = "tgw-rt-spoke" }
}

################################################################################
# Route Table Associations
################################################################################

locals {
  tgw_associations = {
    connect_peer = {
      attachment_id  = aws_ec2_transit_gateway_connect_peer.this[0].transit_gateway_attachment_id
      route_table_id = module.tgw[0].ec2_transit_gateway_route_table_id
    }
    spoke_vpc = {
      attachment_id  = module.spoke_vpc[0].transit_gateway_attachment_id
      route_table_id = aws_ec2_transit_gateway_route_table.spoke.id
    }
  }

  tgw_propagations = {
    connect_peer = {
      attachment_id  = aws_ec2_transit_gateway_connect_peer.this[0].transit_gateway_attachment_id
      route_table_id = aws_ec2_transit_gateway_route_table.spoke.id
    }
    spoke_vpc = {
      attachment_id  = module.spoke_vpc[0].transit_gateway_attachment_id
      route_table_id = module.tgw[0].ec2_transit_gateway_route_table_id
    }
  }
}

resource "aws_ec2_transit_gateway_route_table_association" "this" {
  for_each = local.tgw_associations

  transit_gateway_attachment_id  = each.value.attachment_id
  transit_gateway_route_table_id = each.value.route_table_id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "this" {
  for_each = local.tgw_propagations

  transit_gateway_attachment_id  = each.value.attachment_id
  transit_gateway_route_table_id = each.value.route_table_id
}
