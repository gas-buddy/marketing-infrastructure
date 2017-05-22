resource "aws_db_subnet_group" "cluster_db" {
    name = "${var.cluster_name}-db"
    description = "db subnets for ${var.cluster_name} applications"
    subnet_ids = ["${var.rds_subnet_0_id}","${var.rds_subnet_1_id}","${var.rds_subnet_2_id}"]
}

resource "aws_security_group" "rds"  {
    name = "rds"
    vpc_id = "${var.cluster_vpc_id}"
    description = "rds"

    # Allow all outbound traffic
    egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }

    # Allow MySQL access
    ingress {
      from_port = 3306
      to_port = 3306
      protocol = "tcp"
      security_groups = ["${var.cluster_default_security_group}"]
    }

    tags {
        Name = "${var.cluster_name}-rds"
    }
}
