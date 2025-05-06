output "route_server_id" {
  value       = awscc_ec2_route_server.this[0].route_server_id
  description = "ID of the EC2 Route Server"
}
