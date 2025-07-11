# AWS VPC GRE Connect

**Author:** Mritunjay Bhardwaj  
**Email:** mritunjay.bhardwaj@mbtux.com

This project demonstrates how to implement a Transit Gateway Connect attachment with GRE tunnels for AWS networking. It creates a scalable and resilient network architecture using AWS Transit Gateway, EC2 instances running FRR (Free Range Routing), and GRE tunnels to establish BGP peering.

## Architecture Overview

The solution deploys the following components:

- **Transit Gateway**: Central hub for routing between VPCs and on-premises networks
- **Transit Gateway Connect**: Attachment that enables high-performance connectivity
- **Network Virtual Appliances (NVAs)**: EC2 instances running FRR for BGP routing
- **GRE Tunnels**: Configured between NVAs and Transit Gateway Connect peers
- **BGP Peering**: Established between NVAs and Transit Gateway for dynamic routing
- **Spoke VPC**: Demonstrates connectivity through the Transit Gateway

## Architecture Diagram

```
┌────────────────────────────────────────────────────────────────────────────────────────────┐
│                                AWS Cloud Environment                                       │
│                                                                                            │
│    ┌────────────────────────────────────────────────────────────────────────────────────┐  │
│    │                                AWS Transit Gateway                                 │  │
│    │                                  ASN: 64532                                        │  │
│    │                              CIDR: 192.168.0.0/24                                  │  │
│    └──────────────────────────────┬─────────────────────────────────────────────────────┘  │
│                                   │                                                       │
│                                   │ TGW Connect Attachment                                │
│                                   │                                                       │
│    ┌──────────────────────────────▼────────────────────────────────────────────────────┐  │
│    │                                TGW Connect Peers                                   │  │
│    │    Peer 1: 169.254.200.0/29       │      Peer 2: 169.254.201.0/29                   │  │
│    │    TGW IP: 192.168.0.10          │      TGW IP: 192.168.0.11                        │  │
│    └─────────────────────┬───────────┴────────────┬─────────────────────────────────────┘  │
│                          │                        │                                        │
│                          │ GRE Tunnels            │ VPC Attachment                         │
│                          │                        │                                        │
│  ┌───────────────────────▼────────────────┐   ┌───▼─────────────────────────────────────┐│
│  │              NVA VPC                  │   │               Spoke VPC                 ││
│  │            CIDR: 100.64.0.0/20        │   │           CIDR: 100.64.16.0/20          ││
│  │                                       │   │                                         ││
│  │  ┌──────────────────────────────────┐ │   │ ┌─────────────────────────────────────┐ ││
│  │  │        Public Subnets            │ │   │ │         Private Subnets            │ ││
│  │  │   100.64.0.0/24 (AZ-a)           │ │   │ │      100.64.16.0/24 (AZ-a)         │ ││
│  │  │   100.64.1.0/24 (AZ-b)           │ │   │ │      100.64.17.0/24 (AZ-b)         │ ││
│  │  └──────────────────────────────────┘ │   │ └─────────────────────────────────────┘ ││
│  │                                       │   │                                         │ │
│  │  ┌──────────────┐   ┌──────────────┐  │   │ ┌─────────────────────────────────────┐ ││
│  │  │ FRR Instance │   │ FRR Instance │  │   │ │            Test Instance           │ ││
│  │  │    AZ-a      │   │    AZ-b      │  │   │ │                                     │ ││
│  │  │  ASN: 65001  │   │  ASN: 65001  │  │   │ │       (Connectivity Testing)        │ ││
│  │  │100.64.2.100  │   │100.64.3.100  │  │   │ │                                     │ ││
│  │  │ Loopback:    │   │ Loopback:    │  │   │ │                                     │ ││
│  │  │172.16.0.10/32│   │172.16.0.11/32│  │   │ │                                     │ ││
│  │  └──────┬───────┘   └──────┬───────┘  │   │ └─────────────────────────────────────┘ ││
│  │         │                  │          │   │                                         │ │
│  │         └──────────────────┼──────────┘   │                                         │ │
│  │                iBGP        │              │                                         │ │
│  │         (169.254.6.0/29)   │              │                                         │ │
│  └────────────────────────────┘              └─────────────────────────────────────────┘│
│                                                                                            │
│  BGP Peering Details:                                                                      │
│  • iBGP between NVA instances (ASN 65001)                                                  │
│  • eBGP between NVAs and Transit Gateway (ASN 64532)                                       │
│  • Route advertisement: Loopback networks (172.16.0.0/24)                                  │
│  • Path preference using MED attributes                                                    │
│                                                                                            │
└────────────────────────────────────────────────────────────────────────────────────────────┘

                                         │
                                         │ Future Connectivity
                                         ▼
                             ┌──────────────────────────────┐
                             │                              │
                             │   On-premises or             │
                             │   Other Networks             │
                             │                              │
                             └──────────────────────────────┘

```
For a more detailed diagram, consider creating one using AWS Architecture diagrams or tools like draw.io, and place it in a `docs/` directory.

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

## GitHub Actions CI/CD Setup

This project includes GitHub Actions workflows for automated Terraform deployment using OpenID Connect (OIDC) for secure AWS authentication.

### Prerequisites for GitHub Actions

1. **AWS IAM OIDC Identity Provider**: Create an OIDC identity provider in your AWS account
2. **IAM Role**: Create an IAM role that can be assumed by GitHub Actions
3. **Repository Secrets**: Configure the required secrets in your GitHub repository

### Setting up AWS OIDC for GitHub Actions

#### Step 1: Create OIDC Identity Provider in AWS

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

#### Step 2: Create IAM Role Trust Policy

Create a trust policy file `github-actions-trust-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT-ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:mrbhardw-dev/aws-vpc-gre-connect:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

#### Step 3: Create IAM Role

```bash
aws iam create-role \
  --role-name GitHubActions-TerraformRole \
  --assume-role-policy-document file://github-actions-trust-policy.json
```

#### Step 4: Create and Attach IAM Policy

Create a policy file `terraform-permissions.json` with the necessary permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "iam:*",
        "logs:*",
        "s3:*"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateTransitGateway*",
        "ec2:DeleteTransitGateway*",
        "ec2:DescribeTransitGateway*",
        "ec2:ModifyTransitGateway*",
        "ec2:CreateTransitGatewayConnect*",
        "ec2:DeleteTransitGatewayConnect*",
        "ec2:AcceptTransitGatewayVpcAttachment",
        "ec2:CreateTransitGatewayVpcAttachment",
        "ec2:DeleteTransitGatewayVpcAttachment"
      ],
      "Resource": "*"
    }
  ]
}
```

Create and attach the policy:

```bash
# Create the policy
aws iam create-policy \
  --policy-name TerraformDeploymentPolicy \
  --policy-document file://terraform-permissions.json

# Attach the policy to the role
aws iam attach-role-policy \
  --role-name GitHubActions-TerraformRole \
  --policy-arn arn:aws:iam::ACCOUNT-ID:policy/TerraformDeploymentPolicy
```

#### Step 5: Configure GitHub Repository Secrets

In your GitHub repository, go to Settings > Secrets and variables > Actions, and add:

- **Secret Name**: `AWS_ROLE_TO_ASSUME`
- **Secret Value**: `arn:aws:iam::ACCOUNT-ID:role/GitHubActions-TerraformRole`

#### Step 6: Configure Terraform Backend (Optional)

For production use, configure a Terraform backend. Create a `backend.tf` file:

```hcl
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "aws-vpc-gre-connect/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

### GitHub Actions Workflow

The included workflow (`.github/workflows/terraform.yml`) will:

1. **On Pull Request**: Run `terraform plan` to show proposed changes
2. **On Push to Main**: Run `terraform apply` to deploy changes
3. **Security**: Use OIDC for secure, keyless authentication
4. **Validation**: Check Terraform formatting and validate configuration

### Manual Deployment

For manual deployment without GitHub Actions:

1. Clone this repository:
```bash
git clone https://github.com/mrbhardw-dev/aws-vpc-gre-connect.git
cd aws-vpc-gre-connect
```

2. Initialize Terraform:
```bash
terraform init
```

3. Review and modify variables in `variables.tf` as needed:
   - `region`: AWS region to deploy resources
   - `instance_type`: EC2 instance type for NVAs
   - `connect_peer_cidr_blocks`: CIDR blocks for Transit Gateway Connect peers
   - `transit_gateway_address`: Outside IP addresses for GRE tunnels

4. Deploy the infrastructure:
```bash
terraform plan
terraform apply
```

5. Verify the deployment:
   ```bash
   # Check EC2 instances are running
   aws ec2 describe-instances --filters "Name=tag:Name,Values=*frr-instance*" --query 'Reservations[].Instances[].State.Name'
   
   # Verify BGP sessions (SSH to NVA instance)
   ssh -i your-key.pem ubuntu@<nva-public-ip>
   sudo vtysh -c "show ip bgp summary"
   
   # Test connectivity from spoke instance
   ssh -i your-key.pem ubuntu@<spoke-private-ip>
   ping 172.16.0.10  # Ping NVA loopback
   ```

## Network Configuration

The solution creates:

- NVA VPC with CIDR `100.64.0.0/20`
- Spoke VPC with CIDR `100.64.16.0/20`
- Transit Gateway with CIDR `192.168.0.0/24`
- GRE tunnels with inside CIDRs `169.254.200.0/29` and `169.254.201.0/29`
- BGP peering with ASNs:
  - Transit Gateway ASN: 64532
  - NVA ASN: 65001

## Project Structure

```
├── .github/
│   └── workflows/
│       └── terraform.yml          # GitHub Actions CI/CD pipeline
├── templates/
│   └── bgp_config.sh.tpl          # FRR BGP configuration template
├── rendered/                      # Generated user data scripts
├── data.tf                        # Data sources (AMI lookup)
├── Design.jpg                     # Architecture diagram image
├── endpoint.tf                    # VPC endpoints configuration
├── instance.tf                    # EC2 instance configurations
├── labels.tf                      # Resource labeling and tagging
├── locals.tf                      # Local variables and CIDR calculations
├── network.tf                     # VPC and networking resources
├── output.tf                      # Terraform outputs
├── provider.tf                    # Terraform provider configuration
├── security_group.tf              # Security group definitions
├── tgw_connect.tf                 # Transit Gateway and Connect resources
├── user_data.tpl                  # Legacy user data template
├── variables.tf                   # Input variables
└── README.md                      # This file
```

## Components

### EC2 Instances

Two EC2 instances are deployed in the NVA VPC, each configured with:
- Ubuntu AMI with FRR (Free Range Routing) software
- BGP routing with Transit Gateway Connect peers
- GRE tunnels for encapsulation
- Loopback interfaces for route advertisement
- High-availability deployment across multiple AZs

### Transit Gateway

A Transit Gateway is deployed with:
- Connect attachment to the NVA VPC
- Connect peers for GRE tunneling (2 peers for redundancy)
- Custom route tables for traffic management
- BGP peering with NVA instances

### VPCs

- **NVA VPC** (`100.64.0.0/20`): Contains the FRR routing instances and Transit Gateway attachment
- **Spoke VPC** (`100.64.16.0/20`): Demonstrates connectivity through the Transit Gateway

## Customization

### Configuration Files

- **`variables.tf`**: Modify deployment parameters (region, instance types, CIDR blocks)
- **`locals.tf`**: Adjust CIDR allocations and network design calculations
- **`templates/bgp_config.sh.tpl`**: Customize FRR BGP configuration and routing policies
- **`security_group.tf`**: Modify security group rules for access control

### Common Customizations

1. **Change AWS Region**:
   ```hcl
   variable "region" {
     default = "us-west-2"  # Change from eu-west-1
   }
   ```

2. **Modify Instance Types**:
   ```hcl
   variable "instance_type" {
     default = "c5n.large"  # For higher network performance
   }
   ```

3. **Adjust CIDR Blocks**:
   ```hcl
   variable "aws_cidr_block" {
     default = "10.0.0.0/16"  # Use different IP range
   }
   ```

4. **Configure SSH Key**:
   ```hcl
   # In instance.tf, replace hardcoded key name
   key_name = var.ssh_key_name
   ```

## Troubleshooting

### Common Issues and Solutions

#### BGP Sessions Not Establishing

1. **Check Security Groups**:
   ```bash
   # Verify BGP traffic is allowed (TCP port 179)
   aws ec2 describe-security-groups --group-ids sg-xxxxxxxxx
   ```

2. **Verify GRE Tunnels**:
   ```bash
   # SSH to NVA instance and check GRE tunnel status
   sudo ip tunnel show
   sudo ip addr show gre1
   sudo ip addr show gre2
   ```

3. **Check FRR BGP Status**:
   ```bash
   # Connect to FRR daemon
   sudo vtysh
   show ip bgp summary
   show ip bgp neighbors
   ```

4. **Review Instance Logs**:
   ```bash
   # Check user data execution logs
   sudo tail -f /var/log/cloud-init-output.log
   sudo cat /var/log/bgp_setup.log
   ```

#### Connectivity Issues

1. **Verify Route Propagation**:
   ```bash
   # Check Transit Gateway route tables
   aws ec2 describe-transit-gateway-route-tables
   aws ec2 search-transit-gateway-routes --transit-gateway-route-table-id tgw-rtb-xxxxxxxxx
   ```

2. **Check Source/Destination Check**:
   ```bash
   # Verify source/destination check is disabled on NVA instances
   aws ec2 describe-instance-attribute --instance-id i-xxxxxxxxx --attribute sourceDestCheck
   ```

3. **Verify IP Forwarding**:
   ```bash
   # SSH to NVA instance and check IP forwarding
   cat /proc/sys/net/ipv4/ip_forward  # Should return 1
   ```

#### GitHub Actions Issues

1. **OIDC Authentication Failures**:
   - Verify the IAM role trust policy includes the correct repository path
   - Check that the OIDC provider thumbprint is correct
   - Ensure the role has necessary permissions

2. **Terraform State Issues**:
   - Configure remote state backend for team collaboration
   - Use state locking with DynamoDB to prevent conflicts

3. **Permission Errors**:
   - Review CloudTrail logs for specific permission denials
   - Apply principle of least privilege to IAM policies

## Contributing

Contributions to improve the solution are welcome. Please follow standard Git workflow:

1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## Security Considerations

- **IAM Roles**: Use least privilege principle for all IAM roles
- **Security Groups**: Restrict access to specific IP ranges where possible
- **Encryption**: All EBS volumes are encrypted by default
- **VPC Flow Logs**: Enabled for network monitoring and troubleshooting
- **SSH Access**: Limited to specific management IP addresses

## Cost Optimization

- **Instance Types**: Default uses t3.xlarge, adjust based on throughput requirements
- **EBS Volumes**: Uses gp3 volumes for cost-effective performance
- **NAT Gateways**: Deployed in all AZs for high availability (consider cost vs. availability trade-offs)
- **Transit Gateway**: Charges apply for attachments and data processing

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes with proper documentation
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.