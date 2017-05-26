variable "instance-type" {
  default = {
    bastion = "t2.nano"
    pki = "t2.nano"
    etcd = "m3.large"
    worker = "m3.large"
  }
}

variable "instance-count" {
  default = {
    bastion = "1"
    pki = "1"
    etcd = "3"
    worker = "3"
  }
}
