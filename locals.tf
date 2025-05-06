locals {
  # Allocate a /20 subnet from the /16 CIDR for NVA VPC
  nva_vpc_cidr   = cidrsubnet(var.aws_cidr_block, 4, 0)
  spoke_vpc_cidr = cidrsubnet(var.aws_cidr_block, 4, 1)

  # Create two /22 private subnets within the /20 NVA VPC CIDR
  nva_private_subnets = [
    cidrsubnet(local.nva_vpc_cidr, 4, 0),
    cidrsubnet(local.nva_vpc_cidr, 4, 1)
  ]
  private_subnet_ids_indexed = {
    for idx, id in local.private_subnet_ids : idx => id
  }
  private_subnet_ids       = [for _, value in module.nva_vpc[0].private_subnet_attributes_by_az : value.id]
  spoke_private_subnet_ids = [for _, value in module.spoke_vpc[0].private_subnet_attributes_by_az : value.id]
  public_subnet_ids        = [for _, value in module.nva_vpc[0].public_subnet_attributes_by_az : value.id]
  transit_gateway_subnet_rt_map = {
    for i, id in [for _, value in module.nva_vpc[0].rt_attributes_by_type_by_az.transit_gateway : value.id] :
    "route${i + 1}" => id
  }
  # Allocate another /20 subnet from the /16 CIDR for Transit Gateway
  transit_gateway_cidr_block = ["192.168.0.0/24"]
  azs                        = ["${var.region}a", "${var.region}b"]


  vpc_id_to_lookup = module.nva_vpc[0].vpc_attributes.id


  # Assuming you have access to attachment metadata

  # attachment_id_for_vpc = one([
  #   for i, a in module.tgw[0].ec2_transit_gateway_vpc_attachment_ids : a
  #   if module.tgw[0].aws_ec2_transit_gateway_vpc_attachment[i].vpc_id == local.vpc_id_to_lookup
  # ])

}