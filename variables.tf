variable "enable_stack" {
  type    = bool
  default = true
}
variable "aws_cidr_block" {
  type    = string
  default = "100.64.0.0/16"
}

variable "region" {
  type    = string
  default = "eu-west-1"

}

variable "namespace" {
  type        = string
  description = "namespace, which could be your organization name, e.g. amazon"
  default     = "euw1"
}

variable "env" {
  type        = string
  description = "environment, e.g. 'sit', 'uat', 'prod' etc"
  default     = "prod"
}

variable "project" {
  type        = string
  description = "environment, e.g. 'sit', 'uat', 'prod' etc"
  default     = "bgp"
}

variable "account" {
  type        = string
  description = "account, which could be AWS Account Name or Number"
  default     = ""
}

variable "name" {
  type        = string
  description = "stack name"
  default     = "nva"
}

variable "instance_type" {
  type    = string
  default = "t3.xlarge"

}

variable "prefixes" {
  type        = map(string)
  description = "(optional) describe your variable"

  default = {
    primary  = "10.0.0.0/8",
    internal = "192.168.0.0/16"
  }
}



variable "connect_peer_cidr_blocks" {
  description = "cidr blocks for connect peer"
  default     = ["169.254.200.0/29", "169.254.201.0/29"]
  type        = list(string)
}

variable "transit_gateway_address" {
  description = "Outside IP address of GRE Tunnel "
  default     = ["192.168.0.10", "192.168.0.11"]
  type        = list(string)
}