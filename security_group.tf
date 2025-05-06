module "security_group_nva" {
  source          = "terraform-aws-modules/security-group/aws"
  version         = "5.3.0"
  count           = var.enable_stack ? 1 : 0
  name            = "${module.label.id}-connect-sg-01"
  use_name_prefix = false
  description     = "Security group which is used as an argument in complete-sg"
  vpc_id          = module.nva_vpc[0].vpc_attributes.id
  ingress_with_cidr_blocks = [
    {
      rule        = "ssh-tcp"
      cidr_blocks = "54.240.197.224/32"


    },
    {
      rule        = "all-all"
      cidr_blocks = "${local.spoke_vpc_cidr}"


    },
    {
      rule        = "all-all"
      cidr_blocks = "${local.nva_vpc_cidr}"
    },
    {
      rule        = "all-all"
      cidr_blocks = "192.168.0.0/24"
    }
  ]

  egress_with_cidr_blocks = [
    {
      rule        = "all-all"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
}

module "security_group_spoke" {
  source          = "terraform-aws-modules/security-group/aws"
  version         = "5.3.0"
  count           = var.enable_stack ? 1 : 0
  name            = "${module.label.id}-spoke-sg-01"
  use_name_prefix = false
  description     = "Security group which is used as an argument in complete-sg"
  vpc_id          = module.spoke_vpc[0].vpc_attributes.id
  ingress_with_cidr_blocks = [
    {
      rule        = "all-all"
      cidr_blocks = "172.16.0.0/24"


    },
    {
      rule        = "all-all"
      cidr_blocks = "${local.spoke_vpc_cidr}"
    }
  ]

  egress_with_cidr_blocks = [
    {
      rule        = "all-all"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
}