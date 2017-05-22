module "cache" {
  source = "../../modules/cluster"

  # cluster varaiables
  cluster_name = "${var.cluster_name}"
  asg_name = "cache"

  # a list of subnet IDs to launch resources in.
  cluster_vpc_zone_identifiers = "${var.cache_subnet_0_id},${var.cache_subnet_1_id},${var.cache_subnet_2_id}"
  cluster_min_size = 1
  cluster_max_size = 3
  cluster_desired_capacity = 1
  cluster_security_groups = ["${var.cluster_default_security_group}","${aws_security_group.cache.id}"]

  # Instance specifications
  ami = "${var.ami}"
  image_type = "t2.medium"
  keypair = "${var.cluster_name}-cache"

  # Note: currently cache launch_configuration devices can NOT be changed after cache cluster is up
  # See https://github.com/hashicorp/terraform/issues/2910
  # Instance disks
  root_volume_type = "gp2"
  root_volume_size = 12
  docker_volume_type = "gp2"
  docker_volume_size = 12
  data_volume_type = "gp2"
  data_volume_size = 100

  user_data = "${data.template_file.cache_cloud_config.rendered}"
  iam_role_policy = "${data.template_file.cache_policy_json.rendered}"
}

# Upload CoreOS cloud-config to a s3 bucket; s3-cloudconfig-bootstrap script in user-data will download 
# the cloud-config upon reboot to configure the system. This avoids rebuilding machines when 
# changing cloud-config.
resource "aws_s3_bucket_object" "cache_cloud_config" {
  bucket = "${var.s3_cloudinit_bucket}"
  key = "cache/cloud-config.yaml"
  content = "${data.template_file.cache_cloud_config.rendered}"
}

data "template_file" "cache_cloud_config" {
    template = "${file("../cloud-config/cache.yaml.tmpl")}"
    vars {
        "AWS_ACCOUNT" = "${var.aws_account["id"]}"
        "AWS_USER" = "${var.deployment_user}"
        "AWS_ACCESS_KEY_ID" = "${var.deployment_key_id}"
        "AWS_SECRET_ACCESS_KEY" = "${var.deployment_key_secret}"
        "AWS_DEFAULT_REGION" = "${var.aws_account["default_region"]}"
        "AWS_EFS_ID" = "${var.efs_file_system_efs_id}"
        "CLUSTER_NAME" = "${var.cluster_name}"
        "ELB_WEB_DNS_NAME" = "${var.elb_web_dns_name}"
    }
}

data "template_file" "cache_policy_json" {
    template = "${file("../policies/cache_policy.json")}"
    vars {
        "AWS_ACCOUNT" = "${var.aws_account["id"]}"
        "CLUSTER_NAME" = "${var.cluster_name}"
    }
}

resource "aws_security_group" "cache"  {
  name = "${var.cluster_name}-cache"
  vpc_id = "${var.cluster_vpc_id}"
  description = "cache"
  # Hacker's note: the cloud_config has to be uploaded to s3 before instances fireup
  # but module can't have 'depends_on', so we have to make 
  # this indrect dependency through security group
  depends_on = ["aws_s3_bucket_object.cache_cloud_config"]

  # Allow all outbound traffic
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    security_groups = ["${var.elb_web_security_group}"]
  }

  # Allow SSH from my hosts
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp" 
    cidr_blocks = ["${split(",", var.allow_ssh_cidr)}"]
  }

  tags {
    Name = "${var.cluster_name}-cache"
  }
}

output "cache_security_group" { value = "${aws_security_group.cache.id}" }
output "cache_instances" { value = ["${aws}"] }
