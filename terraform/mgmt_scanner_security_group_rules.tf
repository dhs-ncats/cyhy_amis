# Allow ingress from the bastion security group via the ssh and Nessus ports
resource "aws_security_group_rule" "mgmt_scanner_ingress_from_bastion_sg" {
  count = "${length(local.mgmt_trusted_ingress_ports)}"

  security_group_id = "${aws_security_group.mgmt_scanner_sg.id}"
  type = "ingress"
  protocol = "tcp"
  source_security_group_id = "${aws_security_group.mgmt_bastion_sg.id}"
  from_port = "${local.mgmt_trusted_ingress_ports[count.index]}"
  to_port = "${local.mgmt_trusted_ingress_ports[count.index]}"
}

# Allow ingress from Management, CyHy, and BOD VPCs via all ephemeral tcp ports,
# for internal scanning
resource "aws_security_group_rule" "mgmt_scanner_ingress_tcp_from_cyhy_and_bod_vpc" {
  count = "${var.enable_mgmt_vpc_access_to_all_vpcs}"

  security_group_id = "${aws_security_group.mgmt_scanner_sg.id}"
  type = "ingress"
  protocol = "tcp"
  cidr_blocks = [
    "${aws_vpc.mgmt_vpc.cidr_block}",
    "${aws_vpc.cyhy_vpc.cidr_block}",
    "${aws_vpc.bod_vpc.cidr_block}"
  ]
  from_port = 1024
  to_port = 65535
}

# Allow ingress from Management, CyHy, and BOD VPCs via all ephemeral udp ports,
# for internal scanning
resource "aws_security_group_rule" "mgmt_scanner_ingress_udp_from_cyhy_and_bod_vpc" {
  count = "${var.enable_mgmt_vpc_access_to_all_vpcs}"

  security_group_id = "${aws_security_group.mgmt_scanner_sg.id}"
  type = "ingress"
  protocol = "udp"
  cidr_blocks = [
    "${aws_vpc.mgmt_vpc.cidr_block}",
    "${aws_vpc.cyhy_vpc.cidr_block}",
    "${aws_vpc.bod_vpc.cidr_block}"
  ]
  from_port = 1024
  to_port = 65535
}

# Allow ingress from Management, CyHy, and BOD VPCs via all icmp ports,
# for internal scanning
resource "aws_security_group_rule" "mgmt_scanner_ingress_icmp_from_cyhy_and_bod_vpc" {
  count = "${var.enable_mgmt_vpc_access_to_all_vpcs}"

  security_group_id = "${aws_security_group.mgmt_scanner_sg.id}"
  type = "ingress"
  protocol = "icmp"
  cidr_blocks = [
    "${aws_vpc.mgmt_vpc.cidr_block}",
    "${aws_vpc.cyhy_vpc.cidr_block}",
    "${aws_vpc.bod_vpc.cidr_block}"
  ]
  from_port = -1
  to_port = -1
}

# Allow egress to Management, CyHy, and BOD 18-01 VPCs via all ports and
# protocols, for internal scanning
resource "aws_security_group_rule" "mgmt_scanner_egress_to_cyhy_and_bod_vpc" {
  count = "${var.enable_mgmt_vpc_access_to_all_vpcs}"

  security_group_id = "${aws_security_group.mgmt_scanner_sg.id}"
  type = "egress"
  protocol = "-1"
  cidr_blocks = [
    "${aws_vpc.mgmt_vpc.cidr_block}",
    "${aws_vpc.cyhy_vpc.cidr_block}",
    "${aws_vpc.bod_vpc.cidr_block}"
  ]
  from_port = 0
  to_port = 0
}

# Allow HTTPS egress anywhere; needed for Nessus plugin updates
resource "aws_security_group_rule" "mgmt_scanner_https_egress_to_anywhere" {
  count = "${length(local.mgmt_scanner_egress_anywhere_ports)}"

  security_group_id = "${aws_security_group.mgmt_scanner_sg.id}"
  type = "egress"
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  from_port = "${local.mgmt_scanner_egress_anywhere_ports[count.index]}"
  to_port = "${local.mgmt_scanner_egress_anywhere_ports[count.index]}"
}