# AWS VPC GRE Connect

This project demonstrates how to implement a Transit Gateway Connect attachment with GRE tunnels for AWS networking. It creates a scalable and resilient network architecture using AWS Transit Gateway, EC2 instances running FRR (Free Range Routing), and GRE tunnels to establish BGP peering.

## Architecture Overview

The solution deploys the following components:

- **Transit Gateway**: Central hub for routing between VPCs and on-premises networks
- **Transit Gateway Connect**: Attachment that enables high-performance connectivity
- **Network Virtual Appliances (NVAs)**: EC2 instances running FRR for BGP routing
- **GRE Tunnels**: Configured between NVAs and Transit Gateway Connect peers
- **BGP Peering**: Established between NVAs and Transit Gateway for dynamic routing
- **Spoke VPC**: Demonstrates connectivity through the Transit Gateway

## Key Features

- High-availability design with redundant NVAs across multiple AZs
- BGP routing with path preference using MED attributes
- GRE tunneling for encapsulation of traffic
- Automated configuration of FRR using user data scripts
- Complete infrastructure as code using Terraform

## Prerequisites

- AWS Account with appropriate permissions
- Terraform v1.0.0 or newer
- AWS CLI configured with appropriate credentials

## Deployment

1. Clone this repository:
```
git clone https://gitlab.aws.dev/mrbhardw/aws-vpc-gre-connect.git
cd aws-vpc-gre-connect
```

2. Initialize Terraform:
```
terraform init
```

3. Review and modify variables in `variables.tf` as needed:
   - `region`: AWS region to deploy resources
   - `instance_type`: EC2 instance type for NVAs
   - `connect_peer_cidr_blocks`: CIDR blocks for Transit Gateway Connect peers
   - `transit_gateway_address`: Outside IP addresses for GRE tunnels

4. Deploy the infrastructure:
```
terraform apply
```

5. Verify the deployment:
   - Check EC2 instances are running
   - Verify BGP sessions are established
   - Test connectivity between VPCs

## Network Configuration

The solution creates:

- NVA VPC with CIDR `100.64.0.0/20`
- Spoke VPC with CIDR `100.64.16.0/20`
- Transit Gateway with CIDR `192.168.0.0/24`
- GRE tunnels with inside CIDRs `169.254.200.0/29` and `169.254.201.0/29`
- BGP peering with ASNs:
  - Transit Gateway ASN: 64532
  - NVA ASN: 65001
  - Route Server ASN: 64512 (when enabled)

## Components

### EC2 Instances

Two EC2 instances are deployed in the NVA VPC, each configured with:
- Ubuntu AMI
- FRR for BGP routing
- GRE tunnels for Transit Gateway Connect
- Loopback interfaces for BGP peering

### Transit Gateway

A Transit Gateway is deployed with:
- Connect attachment to the NVA VPC
- Connect peers for GRE tunneling
- Route tables for traffic management
- BGP peering with NVAs

### VPCs

- **NVA VPC**: Contains the routing instances and Transit Gateway attachment
- **Spoke VPC**: Demonstrates connectivity through the Transit Gateway

## Customization

You can customize the deployment by modifying:

- `variables.tf`: Change deployment parameters
- `locals.tf`: Adjust CIDR allocations and network design
- `templates/bgp_config.sh.tpl`: Modify BGP configuration

## Troubleshooting

Common issues and solutions:

1. **BGP sessions not establishing**:
   - Check security groups allow BGP traffic (TCP port 179)
   - Verify GRE tunnels are properly configured
   - Check instance user data logs for configuration errors

2. **Connectivity issues**:
   - Verify route propagation in Transit Gateway route tables
   - Check that source/destination check is disabled on EC2 instances
   - Ensure IP forwarding is enabled on the instances

## Contributing

Contributions to improve the solution are welcome. Please follow standard Git workflow:

1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## License

This project is licensed under standard AWS terms.