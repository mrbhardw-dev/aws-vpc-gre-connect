output "subnet_ids" {
  description = "List of private subnet IDs"
  value       = [for _, value in module.nva_vpc[0].private_subnet_attributes_by_az : value.id]
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = [for _, value in module.nva_vpc[0].public_subnet_attributes_by_az : value.id]
}

output "instance_private_ips" {
  description = "Private IPs of the EC2 instances"
  value       = [for instance in module.ec2_instance : instance.private_ip]
}

output "instance_public_ips" {
  description = "Public IPs of the EC2 instances"
  value       = [for instance in module.ec2_instance : instance.public_ip]
}

output "availability_zones" {
  description = "Availability zones used"
  value       = local.azs
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = var.enable_stack ? module.nva_vpc[0].vpc_attributes.id : null
}

