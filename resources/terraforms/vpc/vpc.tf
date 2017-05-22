data "aws_availability_zones" "available" {}

resource "aws_vpc" "cluster_vpc" {
    cidr_block = "10.10.0.0/16"

    enable_dns_support = true
    enable_dns_hostnames = true
    lifecycle {
        ignore_changes = ["tags"]
    }

    tags {
        Name = "${var.cluster_name}"
    }
    tags {
        Created = "${var.timestamp}-${var.iamuser}-Terraform"
    }
}

resource "aws_internet_gateway" "cluster_vpc" {
    vpc_id = "${aws_vpc.cluster_vpc.id}"

    tags {
        Name = "${var.cluster_name}"
    }
}

resource "aws_route_table" "cluster_vpc" {
    vpc_id = "${aws_vpc.cluster_vpc.id}"
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.cluster_vpc.id}"
    }

    tags {
        Name = "${var.cluster_name}"
    }
}

resource "aws_vpc_endpoint" "s3" {
    vpc_id = "${aws_vpc.cluster_vpc.id}"
    service_name = "com.amazonaws.${var.aws_account["default_region"]}.s3"
    route_table_ids = ["${aws_route_table.cluster_vpc.id}"]
}

resource "aws_default_security_group" "default" {
  vpc_id = "${aws_vpc.cluster_vpc.id}"

  ingress {
    protocol  = -1
    self      = true
    from_port = 0
    to_port   = 0
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

output "cluster_vpc_id" { value = "${aws_vpc.cluster_vpc.id}" }
output "cluster_vpc_cidr" { value = "${aws_vpc.cluster_vpc.cidr_block}" }
output "cluster_availaiblity_zones" { value = "${aws_availability_zones}" }
output "cluster_default_security_group" { value = "${aws_default_security_group.default.id}" }
