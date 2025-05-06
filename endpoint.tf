# module "vpc_endpoints" {
#   source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
#   version = "~> 5.0"

#   vpc_id = module.nva_vpc.vpc_attributes.id

#   endpoints = { for service in toset(["ssm", "ssmmessages", "ec2messages"]) :
#     replace(service, ".", "_") =>
#     {
#       service             = service
#       subnet_ids          = local.private_subnet_ids
#       private_dns_enabled = true
#       tags                = { Name = "${module.label.id}-${service}" }
#     }
#   }

#   create_security_group      = true
#   security_group_name        = "${module.label.id}-vpc-endpoints-01"
#   security_group_description = "VPC endpoint security group"
#   security_group_rules = {
#     ingress_https = {
#       description = "HTTPS from subnets"
#       cidr_blocks = local.nva_private_subnets
#     }
#   }

#   tags = module.label.tags_aws
# }