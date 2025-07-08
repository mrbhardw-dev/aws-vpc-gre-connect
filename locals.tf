################################################################################
# Local Variables and CIDR Calculations
################################################################################

locals {
  ################################################################################
  # VPC CIDR Block Allocation
  ################################################################################
  
  # Subdivide the main CIDR block (100.64.0.0/16) into /20 subnets
  # NVA VPC: 100.64.0.0/20 (first /20 subnet)
  nva_vpc_cidr = cidrsubnet(var.aws_cidr_block, 4, 0)
  
  # Spoke VPC: 100.64.16.0/20 (second /20 subnet)
  spoke_vpc_cidr = cidrsubnet(var.aws_cidr_block, 4, 1)

  ################################################################################
  # Subnet ID Collections
  ################################################################################
  
  # Extract subnet IDs from VPC modules for use in other resources
  private_subnet_ids       = var.enable_stack ? [for _, value in module.nva_vpc[0].private_subnet_attributes_by_az : value.id] : []
  spoke_private_subnet_ids = var.enable_stack ? [for _, value in module.spoke_vpc[0].private_subnet_attributes_by_az : value.id] : []
  public_subnet_ids        = var.enable_stack ? [for _, value in module.nva_vpc[0].public_subnet_attributes_by_az : value.id] : []
  
  # Create indexed mapping of private subnet IDs for reference
  private_subnet_ids_indexed = {
    for idx, id in local.private_subnet_ids : idx => id
  }
  
  # Map Transit Gateway subnet route table IDs for route management
  transit_gateway_subnet_rt_map = var.enable_stack ? {
    for i, id in [for _, value in module.nva_vpc[0].rt_attributes_by_type_by_az.transit_gateway : value.id] :
    "route${i + 1}" => id
  } : {}

  ################################################################################
  # Transit Gateway Configuration
  ################################################################################
  
  # CIDR block for Transit Gateway Connect peer addressing
  # This is separate from VPC CIDRs and used for GRE tunnel endpoints
  transit_gateway_cidr_block = ["192.168.0.0/24"]
  
  ################################################################################
  # Availability Zone Configuration
  ################################################################################
  
  # Define AZs based on the selected region for multi-AZ deployment
  azs = ["${var.region}a", "${var.region}b"]

  ################################################################################
  # VPC Reference for Lookups
  ################################################################################
  
  # NVA VPC ID for reference in other resources
  vpc_id_to_lookup = var.enable_stack ? module.nva_vpc[0].vpc_attributes.id : null
}