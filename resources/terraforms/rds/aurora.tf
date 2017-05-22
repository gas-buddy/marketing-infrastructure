variable "aurora_db_name" { default = "master" }
variable "aurora_db_user" { default = "root" }
variable "aurora_db_password" { default = "dbchangeme" }

resource "aws_rds_cluster_instance" "cluster_instances" {
  count              = 2
  identifier         = "${var.cluster_name}-aurora-cluster-${count.index}"
  cluster_identifier = "${aws_rds_cluster.default.id}"
  instance_class     = "db.r3.large"
  db_subnet_group_name   = "${aws_db_subnet_group.cluster_db.name}"

}

resource "aws_rds_cluster" "default" {
  cluster_identifier = "${var.cluster_name}-aurora-cluster"
  database_name = "${var.aurora_db_name}"
  master_username = "${var.aurora_db_user}"
  master_password = "${var.aurora_db_password}"
  backup_retention_period = 7
  preferred_backup_window = "07:00-09:00"
  vpc_security_group_ids = [ "${aws_security_group.rds.id}" ]
  db_subnet_group_name = "${aws_db_subnet_group.cluster_db.name}"
}
