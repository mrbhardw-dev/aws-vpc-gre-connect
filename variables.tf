################################################################################
# Core Configuration Variables
################################################################################

# Enable/disable the entire stack deployment
variable "enable_stack" {
  type        = bool
  description = "Enable or disable the deployment of the entire stack"
  default     = true
}

# Primary CIDR block for the entire deployment
variable "aws_cidr_block" {
  type        = string
  description = "Primary CIDR block for VPC allocation (will be subdivided)"
  default     = "100.64.0.0/16"
}

################################################################################
# Environment and Naming Variables
################################################################################

# AWS region for deployment
variable "region" {
  type        = string
  description = "AWS region where resources will be deployed"
  default     = "eu-west-1"
}

# Namespace for resource naming
variable "namespace" {
  type        = string
  description = "Namespace for resource naming (e.g., organization name)"
  default     = "euw1"
}

# Environment designation
variable "env" {
  type        = string
  description = "Environment designation (e.g., 'dev', 'staging', 'prod')"
  default     = "prod"
}

# Project identifier
variable "project" {
  type        = string
  description = "Project identifier for resource grouping"
  default     = "bgp"
}

# AWS account identifier
variable "account" {
  type        = string
  description = "AWS Account Name or Number for resource tagging"
  default     = ""
}

# Stack name
variable "name" {
  type        = string
  description = "Stack name for resource identification"
  default     = "nva"
}

################################################################################
# Infrastructure Configuration Variables
################################################################################

# EC2 instance type for NVA instances
variable "instance_type" {
  type        = string
  description = "EC2 instance type for FRR NVA instances"
  default     = "t3.xlarge"
}

# Prefix list for managed CIDR blocks
variable "prefixes" {
  type        = map(string)
  description = "Map of CIDR blocks for managed prefix list"
  default = {
    primary  = "10.0.0.0/8"
    internal = "192.168.0.0/16"
  }
}

################################################################################
# Transit Gateway Connect Configuration
################################################################################

# CIDR blocks for Transit Gateway Connect peers
variable "connect_peer_cidr_blocks" {
  type        = list(string)
  description = "CIDR blocks for Transit Gateway Connect peer inside addresses"
  default     = ["169.254.200.0/29", "169.254.201.0/29"]
}

# Transit Gateway Connect peer outside addresses
variable "transit_gateway_address" {
  type        = list(string)
  description = "Outside IP addresses for GRE tunnels to Transit Gateway Connect peers"
  default     = ["192.168.0.10", "192.168.0.11"]
}