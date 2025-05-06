locals {
  instance_count     = var.enable_stack ? 2 : 0
  base_name          = "${module.label.id}-frr-instance"
  base_iam_role_name = "${module.label.id}-frr-iam-role"

  # Define instance-specific BGP config variables
  bgp_configs = [
    {
      local_as                     = 65001
      remote_as                    = 64512
      tgw_remote_as                = 64532
      router_id                    = "100.64.2.100"
      ebgp_neighbour               = "100.64.2.89"
      ibgp_neighbour               = "169.254.6.2"
      tgw_connect_ebgp_neighbour_1 = "169.254.200.2"
      tgw_connect_ebgp_neighbour_2 = "169.254.200.3"
      bgp_advertised_network       = "172.16.0.10/32"
      primary_route_map            = "PREFER_MED_10"
      secondary_route_map          = "PREFER_MED_20"


      # iBGP GRE Tunnel
      ibgp_gre_local_ip  = "100.64.2.100"
      ibgp_gre_remote_ip = "100.64.3.100"
      ibgp_gre_inside_ip = "169.254.6.1/29"

      # eBGP GRE Tunnel
      ebgp_gre_local_ip  = "100.64.2.100"
      ebgp_gre_remote_ip = "192.168.0.10"
      ebgp_gre_inside_ip = "169.254.200.1/29"

      # Loopback
      loopback_ip = "172.16.0.10"
      LO_IF       = "lo:1"
    },
    {
      local_as                     = 65001
      remote_as                    = 64512
      tgw_remote_as                = 64532
      router_id                    = "100.64.3.100"
      ebgp_neighbour               = "100.64.3.237"
      ibgp_neighbour               = "169.254.6.1"
      tgw_connect_ebgp_neighbour_1 = "169.254.201.2"
      tgw_connect_ebgp_neighbour_2 = "169.254.201.3"
      bgp_advertised_network       = "172.16.0.11/32"
      primary_route_map            = "PREFER_MED_10"
      secondary_route_map          = "PREFER_MED_20"


      # GRE Tunnel
      ibgp_gre_local_ip  = "100.64.3.100"
      ibgp_gre_remote_ip = "100.64.2.100"
      ibgp_gre_inside_ip = "169.254.6.2/29"

      # eBGP GRE Tunnel
      ebgp_gre_local_ip  = "100.64.3.100"
      ebgp_gre_remote_ip = "192.168.0.11"
      ebgp_gre_inside_ip = "169.254.201.1/29"

      # Loopback
      loopback_ip = "172.16.0.11"
      LO_IF       = "lo:1"
    }
  ]

  instance_configs = [
    for i in range(local.instance_count) : {
      name              = "${local.base_name}-${format("%02d", i + 1)}"
      iam_role_name     = "${local.base_iam_role_name}-${format("%02d", i + 1)}"
      availability_zone = element(local.azs, i)
      subnet_id         = element(local.public_subnet_ids, i)
      private_ip        = i == 0 ? "100.64.2.100" : "100.64.3.100"
      bgp_config        = local.bgp_configs[i]
    }
  ]
}


resource "local_file" "user_data" {
  count    = local.instance_count
  content  = templatefile("${path.module}/templates/bgp_config.sh.tpl", local.instance_configs[count.index].bgp_config)
  filename = "${path.module}/rendered/user_data_${count.index}.sh"
}

module "ec2_instance" {
  source                      = "terraform-aws-modules/ec2-instance/aws"
  version                     = "5.8.0"
  count                       = local.instance_count
  source_dest_check           = false
  name                        = local.instance_configs[count.index].name
  key_name                    = "mrbhardw"
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  availability_zone           = local.instance_configs[count.index].availability_zone
  subnet_id                   = local.instance_configs[count.index].subnet_id
  vpc_security_group_ids      = [module.security_group_nva[0].security_group_id]
  create_eip                  = true
  disable_api_stop            = false
  create_iam_instance_profile = true
  iam_role_name               = local.instance_configs[count.index].iam_role_name
  iam_role_use_name_prefix    = false
  iam_role_description        = "IAM role for EC2 instance"
  iam_role_policies = {
    AdministratorAccess = "arn:aws:iam::aws:policy/AdministratorAccess"
  }

  user_data_base64            = base64encode(local_file.user_data[count.index].content)
  private_ip                  = local.instance_configs[count.index].private_ip
  user_data_replace_on_change = true

  cpu_options = {
    core_count       = 2
    threads_per_core = 1
  }

  enable_volume_tags = false
  root_block_device = [{
    encrypted   = true
    volume_type = "gp3"
    throughput  = 200
    volume_size = 50
    tags = {
      Name = "root"
    }
  }]

  ebs_block_device = [{
    device_name = "/dev/sdf"
    volume_type = "gp3"
    volume_size = 5
    throughput  = 200
    tags = {
      MountPoint = "/mnt/data"
    }
  }]

  tags = module.label.tags_aws
}


module "ec2_instance_spoke" {
  source                      = "terraform-aws-modules/ec2-instance/aws"
  version                     = "5.8.0"
  name                        = "${module.label.id}-spoke-instance"
  key_name                    = "mrbhardw"
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  availability_zone           = element(local.azs, 0)
  subnet_id                   = element(local.spoke_private_subnet_ids, 0)
  vpc_security_group_ids      = [module.security_group_spoke[0].security_group_id]
  create_eip                  = false
  disable_api_stop            = false
  create_iam_instance_profile = true
  iam_role_name               = "${module.label.id}-spoke-iam-role-01"
  iam_role_use_name_prefix    = false
  iam_role_description        = "IAM role for EC2 instance"
  iam_role_policies = {
    AdministratorAccess = "arn:aws:iam::aws:policy/AdministratorAccess"
  }


  cpu_options = {
    core_count       = 2
    threads_per_core = 1
  }

  enable_volume_tags = false
  root_block_device = [{
    encrypted   = true
    volume_type = "gp3"
    throughput  = 200
    volume_size = 50
    tags = {
      Name = "root"
    }
  }]

  ebs_block_device = [{
    device_name = "/dev/sdf"
    volume_type = "gp3"
    volume_size = 5
    throughput  = 200
    tags = {
      MountPoint = "/mnt/data"
    }
  }]

  tags = module.label.tags_aws
}
