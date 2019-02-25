# Allow SSH ingress from the bastion security group
resource "aws_security_group_rule" "docker_ssh_ingress_from_bastion" {
  security_group_id = "${aws_security_group.bod_docker_sg.id}"
  type = "ingress"
  protocol = "tcp"
  source_security_group_id = "${aws_security_group.bod_bastion_sg.id}"
  from_port = 22
  to_port = 22
}

# Allow HTTP, HTTPS, SMTP (587), and FTP egress anywhere
resource "aws_security_group_rule" "docker_anywhere" {
  count = "${length(local.bod_docker_egress_anywhere_ports)}"

  security_group_id = "${aws_security_group.bod_docker_sg.id}"
  type = "egress"
  protocol = "tcp"
  cidr_blocks = [
    "0.0.0.0/0"
  ]
  from_port = "${local.bod_docker_egress_anywhere_ports[count.index]}"
  to_port = "${local.bod_docker_egress_anywhere_ports[count.index]}"
}

# Allow ephemeral port egress to anywhere.  This is necessary for
# passive FTP to function.
resource "aws_security_group_rule" "ephemeral_port_egress_anywhere" {
  security_group_id = "${aws_security_group.bod_docker_sg.id}"
  type = "egress"
  protocol = "tcp"
  cidr_blocks = [
    "0.0.0.0/0"
  ]
  from_port = 1024
  to_port = 65535
}

# Allow DNS egress to Google
resource "aws_security_group_rule" "docker_dns_to_google" {
  count = "${length(local.tcp_and_udp)}"

  security_group_id = "${aws_security_group.bod_docker_sg.id}"
  type = "egress"
  protocol = "${local.tcp_and_udp[count.index]}"
  cidr_blocks = [
    "8.8.8.8/32",
    "8.8.4.4/32"
  ]
  from_port = 53
  to_port = 53
}

# Allow egress via the MongoDB port to the "CyHy Private" security
# group
resource "aws_security_group_rule" "docker_egress_to_cyhy_private_via_mongodb" {
  security_group_id = "${aws_security_group.bod_docker_sg.id}"
  type = "egress"
  protocol = "tcp"
  source_security_group_id = "${aws_security_group.cyhy_private_sg.id}"
  from_port = 27017
  to_port = 27017
}

# Allow all ICMP from vulnscanner instance in Management VPC,
# for internal scanning
resource "aws_security_group_rule" "bod_docker_ingress_all_icmp_from_mgmt_vulnscan" {
  count = "${var.enable_mgmt_vpc_access_to_all_vpcs}"

  security_group_id = "${aws_security_group.bod_docker_sg.id}"
  type = "ingress"
  protocol = "icmp"
  cidr_blocks = [
    "${aws_instance.mgmt_nessus.private_ip}/32"
  ]
  from_port = -1
  to_port = -1
}

# Allow all TCP from vulnscanner instance in Management VPC,
# for internal scanning
resource "aws_security_group_rule" "bod_docker_ingress_all_tcp_from_mgmt_vulnscan" {
  count = "${var.enable_mgmt_vpc_access_to_all_vpcs}"

  security_group_id = "${aws_security_group.bod_docker_sg.id}"
  type = "ingress"
  protocol = "tcp"
  cidr_blocks = [
    "${aws_instance.mgmt_nessus.private_ip}/32"
  ]
  from_port = 0
  to_port = 65535
}

# Allow all UDP from vulnscanner instance in Management VPC,
# for internal scanning
resource "aws_security_group_rule" "bod_docker_ingress_all_udp_from_mgmt_vulnscan" {
  count = "${var.enable_mgmt_vpc_access_to_all_vpcs}"

  security_group_id = "${aws_security_group.bod_docker_sg.id}"
  type = "ingress"
  protocol = "udp"
  cidr_blocks = [
    "${aws_instance.mgmt_nessus.private_ip}/32"
  ]
  from_port = 0
  to_port = 65535
}

# Allow all ICMP to vulnscanner instance in Management VPC,
# for internal scanning
resource "aws_security_group_rule" "bod_docker_egress_all_icmp_to_mgmt_vulnscan" {
  count = "${var.enable_mgmt_vpc_access_to_all_vpcs}"

  security_group_id = "${aws_security_group.bod_docker_sg.id}"
  type = "egress"
  protocol = "icmp"
  cidr_blocks = [
    "${aws_instance.mgmt_nessus.private_ip}/32"
  ]
  from_port = -1
  to_port = -1
}

# Allow all TCP to vulnscanner instance in Management VPC,
# for internal scanning
resource "aws_security_group_rule" "bod_docker_egress_all_tcp_to_mgmt_vulnscan" {
  count = "${var.enable_mgmt_vpc_access_to_all_vpcs}"

  security_group_id = "${aws_security_group.bod_docker_sg.id}"
  type = "egress"
  protocol = "tcp"
  cidr_blocks = [
    "${aws_instance.mgmt_nessus.private_ip}/32"
  ]
  from_port = 0
  to_port = 65535
}

# Allow all UDP to vulnscanner instance in Management VPC,
# for internal scanning
resource "aws_security_group_rule" "bod_docker_egress_all_udp_to_mgmt_vulnscan" {
  count = "${var.enable_mgmt_vpc_access_to_all_vpcs}"

  security_group_id = "${aws_security_group.bod_docker_sg.id}"
  type = "egress"
  protocol = "udp"
  cidr_blocks = [
    "${aws_instance.mgmt_nessus.private_ip}/32"
  ]
  from_port = 0
  to_port = 65535
}
