variable "enabled" {
  type    = bool
  default = true
}

variable "name_prefix" {
  type = string
}

variable "tags" {
  type = map(string)
  default = {}
}

variable "vpc_id" {
  type = string
}

variable "amazon_side_asn" {
  type    = number
  default = 64512
}

variable "persist_routes" {
  type    = string
  default = "disable"
}

# variable "persist_routes_duration" {
#   type = number
#   default = "0"
# }

variable "sns_notifications_enabled" {
  type    = bool
  default = false
}

variable "endpoints" {
  type = list(object({
    name_suffix = string
    subnet_id   = string
  }))
  description = "List of endpoints (one per AZ)"
}

variable "peers" {
  type = map(object({
    endpoint_key = string
    peer_ip      = string
  }))
  description = "Map of BGP peers with endpoint_key and peer_ip"
}

variable "bgp_local_as" {
  type = number
}

variable "propagation_route_table_ids" {
  type = map(string)
  description = "Map of route table propagation targets (e.g., { route1 = rt-id-123 })"
}
