################################################################################
# Transit Gateway
################################################################################

# Central Transit Gateway for inter-VPC and Connect attachment routing
# Configured with BGP ASN 64532 for BGP peering with NVA instances
module "tgw" {
  source  = "terraform-aws-modules/transit-gateway/aws"
  version = "2.13.0"
  count   = var.enable_stack ? 1 : 0

  name                        = "${module.label.id}-connect-tgw-01"
  description                 = "Transit Gateway for VPC connectivity and BGP routing"
  amazon_side_asn             = 64532  # BGP ASN for Transit Gateway
  transit_gateway_cidr_blocks = local.transit_gateway_cidr_block

  # Enable features for cross-account sharing and security group referencing
  enable_auto_accept_shared_attachments = true
  enable_sg_referencing_support         = true
  enable_multicast_support              = false
  
  # Resource Access Manager (RAM) configuration for cross-account sharing
  ram_allow_external_principals = true
  ram_principals                = ["058264222681"]  # TODO: Make configurable

  # Route table naming
  tgw_default_route_table_tags = { Name = "tgw-rt-default" }
  tgw_route_table_tags         = { Name = "tgw-rt-connect" }
  tags                         = module.label.tags_aws
}

################################################################################
# Transit Gateway Connect Attachment
################################################################################

# Transit Gateway Connect attachment enables high-performance connectivity
# Uses the NVA VPC attachment as transport for GRE tunnels
resource "aws_ec2_transit_gateway_connect" "this" {
  count = var.enable_stack ? 1 : 0

  transit_gateway_id      = module.tgw[0].ec2_transit_gateway_id
  transport_attachment_id = module.nva_vpc[0].transit_gateway_attachment_id
  
  # Disable default route table association/propagation for custom routing
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = merge(
    { Name = "${module.label.id}-connect-attachment" },
    module.label.tags_aws
  )
}

################################################################################
# Transit Gateway Connect Peers
################################################################################

# Connect peers establish GRE tunnels between Transit Gateway and NVA instances
# Each peer represents one end of a GRE tunnel for BGP peering
resource "aws_ec2_transit_gateway_connect_peer" "this" {
  count = var.enable_stack ? 2 : 0

  # Inside CIDR blocks for GRE tunnel addressing
  inside_cidr_blocks = [var.connect_peer_cidr_blocks[count.index]]
  
  # NVA instance IP address (peer end of GRE tunnel)
  peer_address = module.ec2_instance[count.index].private_ip
  
  # Transit Gateway end of GRE tunnel
  transit_gateway_address = var.transit_gateway_address[count.index]
  
  # Connect attachment ID
  transit_gateway_attachment_id = aws_ec2_transit_gateway_connect.this[0].id
  
  # BGP ASN for the NVA instances
  bgp_asn = "65001"

  tags = merge(
    { Name = "${module.label.id}-connect-peer-${format("%02d", count.index + 1)}" },
    module.label.tags_aws
  )
}

################################################################################
# Custom Route Tables
################################################################################

# Custom route table for spoke VPC traffic
# Separates spoke traffic from connect attachment traffic
resource "aws_ec2_transit_gateway_route_table" "spoke" {
  count              = var.enable_stack ? 1 : 0
  transit_gateway_id = module.tgw[0].ec2_transit_gateway_id

  tags = merge(
    { Name = "${module.label.id}-rt-spoke" },
    module.label.tags_aws
  )
}

################################################################################
# Route Table Associations and Propagations
################################################################################

# Define route table associations and propagations for traffic flow control
locals {
  # Route table associations (which route table an attachment uses)
  tgw_associations = var.enable_stack ? {
    # Connect peer uses the default TGW route table
    connect_peer = {
      attachment_id  = aws_ec2_transit_gateway_connect_peer.this[0].transit_gateway_attachment_id
      route_table_id = module.tgw[0].ec2_transit_gateway_route_table_id
    }
    # Spoke VPC uses the custom spoke route table
    spoke_vpc = {
      attachment_id  = module.spoke_vpc[0].transit_gateway_attachment_id
      route_table_id = aws_ec2_transit_gateway_route_table.spoke[0].id
    }
  } : {}

  # Route propagations (which routes are learned by which route tables)
  tgw_propagations = var.enable_stack ? {
    # Connect peer routes are propagated to spoke route table
    connect_peer = {
      attachment_id  = aws_ec2_transit_gateway_connect_peer.this[0].transit_gateway_attachment_id
      route_table_id = aws_ec2_transit_gateway_route_table.spoke[0].id
    }
    # Spoke VPC routes are propagated to default route table
    spoke_vpc = {
      attachment_id  = module.spoke_vpc[0].transit_gateway_attachment_id
      route_table_id = module.tgw[0].ec2_transit_gateway_route_table_id
    }
  } : {}
}

# Associate attachments with specific route tables
resource "aws_ec2_transit_gateway_route_table_association" "this" {
  for_each = local.tgw_associations

  transit_gateway_attachment_id  = each.value.attachment_id
  transit_gateway_route_table_id = each.value.route_table_id
}

# Propagate routes between route tables for connectivity
resource "aws_ec2_transit_gateway_route_table_propagation" "this" {
  for_each = local.tgw_propagations

  transit_gateway_attachment_id  = each.value.attachment_id
  transit_gateway_route_table_id = each.value.route_table_id
}
