resource "awscc_ec2_route_server" "this" {
  count = var.enabled ? 1 : 0

  amazon_side_asn           = var.amazon_side_asn
  persist_routes            = var.persist_routes
  # persist_routes_duration  = var.persist_routes_duration 
  sns_notifications_enabled = var.sns_notifications_enabled

  tags = [
    for k, v in merge(
      { "Name" = "${var.name_prefix}-route-server" },
      var.tags
    ) : {
      key   = k
      value = v
    }
  ]
}

resource "awscc_ec2_route_server_association" "this" {
  count = var.enabled ? 1 : 0

  route_server_id = awscc_ec2_route_server.this[0].route_server_id
  vpc_id          = var.vpc_id
}

resource "awscc_ec2_route_server_endpoint" "this" {
  for_each = var.enabled ? { for idx, val in var.endpoints : val.name_suffix => val } : {}

  route_server_id = awscc_ec2_route_server.this[0].route_server_id
  subnet_id       = each.value.subnet_id

  tags = [
    for k, v in merge(
      { "Name" = "${var.name_prefix}-endpoint-${each.key}" },
      var.tags
    ) : {
      key   = k
      value = v
    }
  ]
}

resource "awscc_ec2_route_server_peer" "this" {
  for_each = var.enabled ? {
    for k, v in var.peers : k => {
      endpoint_key = v.endpoint_key
      peer_ip      = v.peer_ip
    }
  } : {}

  route_server_endpoint_id = awscc_ec2_route_server_endpoint.this[each.value.endpoint_key].route_server_endpoint_id
  peer_address             = each.value.peer_ip

  bgp_options = {
    peer_asn       = var.bgp_local_as
    amazon_address = awscc_ec2_route_server_endpoint.this[each.value.endpoint_key].eni_address
    peer_address   = each.value.peer_ip
  }

  tags = [
    for k, v in merge(
      { "Name" = "${var.name_prefix}-peer-${each.key}" },
      var.tags
    ) : {
      key   = k
      value = v
    }
  ]
}

resource "awscc_ec2_route_server_propagation" "this" {
  for_each = var.enabled ? var.propagation_route_table_ids : {}

  route_server_id = awscc_ec2_route_server.this[0].route_server_id
  route_table_id  = each.value
}
