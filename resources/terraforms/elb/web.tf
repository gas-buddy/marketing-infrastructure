#
# ELB for Web
#

variable "web_cert" { default = "../certs/site.pem" }
variable "web_cert_chain" { default = "../certs/rootCA.pem" }
variable "web_cert_key" { default = "../certs/site-key.pem" }

resource "aws_elb" "web" {
  name = "${var.cluster_name}-elb-web"
  depends_on = [ "aws_iam_server_certificate.wildcard" ]
  subnets = ["${var.elb_subnet_0_id}","${var.elb_subnet_1_id}","${var.elb_subnet_2_id}"]
  security_groups = [ "${aws_security_group.elb_web.id}" ]

  cross_zone_load_balancing   = true
  idle_timeout                = 400

  listener {
    lb_port = 443
    lb_protocol = "https"
    instance_port = 8080
    instance_protocol = "http"
    ssl_certificate_id = "${aws_iam_server_certificate.wildcard.arn}"
  }

  listener {
    lb_port = 80
    lb_protocol = "http"
    instance_port = 8080
    instance_protocol = "http"
  }

  health_check {
    healthy_threshold = 5
    unhealthy_threshold = 2
    timeout = 3
    target = "TCP:8080"
    interval = 30
  }

  tags {
      Name = "${var.cluster_name}-elb-web"
  }
}

# Upload a example/demo wildcard cert
resource "aws_iam_server_certificate" "wildcard" {
  name = "${var.app_domain}"
  certificate_body = "${file("${var.web_cert}")}"
  certificate_chain = "${file("${var.web_cert_chain}")}"
  private_key = "${file("${var.web_cert_key}")}"

  lifecycle {
    create_before_destroy = true
  }

  provisioner "local-exec" {
    command = <<EOF
echo # Sleep 10 secends so that aws_iam_server_certificate.wildcard is truely setup by aws iam service
echo # See https://github.com/hashicorp/terraform/issues/2499 (terraform ~v0.6.1)
sleep 10
EOF
  }
}

resource "aws_security_group" "elb_web"  {
    name = "${var.cluster_name}-elb-web"
    vpc_id = "${var.cluster_vpc_id}"
    description = "${var.cluster_name} elb-web"

    # Allow all outbound traffic
    egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
      from_port = 80
      to_port = 80
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
      from_port = 443
      to_port = 443
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }

    tags {
      Name = "${var.cluster_name}-elb-web"
    }
}

output "elb_web_security_group" { value = "${aws_security_group.elb_web.id}" }
output "elb_web_name" { value = "${aws_elb.web.name}" }
output "elb_web_dns_name" { value = "${aws_elb.web.dns_name}" }
