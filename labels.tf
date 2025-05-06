module "label" {
  source  = "aws-ia/label/aws"
  version = "0.0.6"

  name      = var.name
  namespace = var.namespace
  env       = var.env
  account   = var.account
  tags = {
    "Created by" = "terraform"
    "Project"    = var.project
    "Owner"      = "IaC team"
    "env"        = var.env
  }
}