data "aws_ami" "nmap" {
  filter {
    name = "name"
    values = [
      "cyhy-nmap-hvm-*-x86_64-ebs"
    ]
  }

  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name = "root-device-type"
    values = ["ebs"]
  }

  owners = ["${data.aws_caller_identity.current.account_id}"] # This is us
  most_recent = true
}

resource "aws_instance" "cyhy_nmap" {
  ami = "${data.aws_ami.nmap.id}"
  instance_type = "${local.production_workspace ? "t2.micro" : "t2.micro"}"
  count = "${local.nmap_instance_count}"

  # ebs_optimized = true
  availability_zone = "${var.aws_region}${var.aws_availability_zone}"
  # We may want to spread instances across all availability zones, however
  # this will also require creating a scanner subnet in each availability zone
  # availability_zone = "${element(data.aws_availability_zones.all.names, count.index)}"

  subnet_id = "${aws_subnet.cyhy_portscanner_subnet.id}"
  associate_public_ip_address = false

  root_block_device {
    volume_type = "gp2"
    volume_size = "${local.production_workspace ? 16 : 8}"
    delete_on_termination = true
  }

  vpc_security_group_ids = [
    "${aws_security_group.cyhy_scanner_sg.id}"
  ]

  user_data = "${data.template_cloudinit_config.ssh_and_cyhy_runner_cloud_init_tasks.rendered}"

  tags = "${merge(var.tags, map("Name", format("CyHy Nmap - portscan%d", count.index+1), "Publish Egress", "True"))}"
  volume_tags = "${merge(var.tags, map("Name", format("CyHy Nmap - portscan%d", count.index+1)))}"
}

# Note that the EBS volume contains production data. Therefore we need
# these resources to be immortal in the "production" workspace, and so
# I am using the prevent_destroy lifecycle element to disallow the
# destruction of it via terraform in that case.
#
# I'd like to use "${terraform.workspace == "production" ? true :
# false}", so the prevent_destroy only applies to the production
# workspace, but it appears that interpolations are not supported
# inside of the lifecycle block
# (https://github.com/hashicorp/terraform/issues/3116).
resource "aws_ebs_volume" "nmap_cyhy_runner_data" {
  count = "${local.nmap_instance_count}"
  availability_zone = "${var.aws_region}${var.aws_availability_zone}"
  # availability_zone = "${element(data.aws_availability_zones.all.names, count.index)}"
  type = "gp2"
  size = "${local.production_workspace ? 2 : 1}"
  encrypted = true

  tags = "${merge(var.tags, map("Name", format("CyHy Nmap - portscan%d", count.index+1)))}"

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_volume_attachment" "nmap_cyhy_runner_data_attachment" {
  count = "${local.nmap_instance_count}"
  device_name = "${var.cyhy_runner_disk}"
  volume_id = "${aws_ebs_volume.nmap_cyhy_runner_data.*.id[count.index]}"
  instance_id = "${aws_instance.cyhy_nmap.*.id[count.index]}"

  # Terraform attempts to destroy the volume attachment before it attempts to
  # destroy the EC2 instance it is attached to.  EC2 does not like that and it
  # results in the failed destruction of the volume attachment.  To get around
  # this, we explicitly terminate the cyhy_nmap instance via the AWS CLI
  # in a destroy provisioner; this gracefully shuts down the instance and
  # allows terraform to successfully destroy the volume attachments.
  provisioner "local-exec" {
    when = "destroy"
    # Use element(aws_instance.cyhy_nmap.*.id, count.index) rather than
    # aws_instance.cyhy_nmap.*.id[count.index] to avoid Terraform 'index out of
    # range' error, similar to the one documented here:
    # https://github.com/hashicorp/terraform/issues/14536#issue-228958605
    command = "aws --region=${var.aws_region} ec2 terminate-instances --instance-ids ${element(aws_instance.cyhy_nmap.*.id, count.index)}"
    on_failure = "continue"
  }

  # Wait until cyhy_nmap instance is terminated before continuing on
  provisioner "local-exec" {
    when = "destroy"
    command = "aws --region=${var.aws_region} ec2 wait instance-terminated --instance-ids ${element(aws_instance.cyhy_nmap.*.id, count.index)}"
  }

  skip_destroy = true
  depends_on = ["aws_ebs_volume.nmap_cyhy_runner_data"]
}

# load in the dynamically created provisioner modules
module "dyn_nmap" {
  source = "./dyn_nmap"
  bastion_public_ip = "${aws_instance.cyhy_bastion.public_ip}"
  nmap_private_ips = "${aws_instance.cyhy_nmap.*.private_ip}"
  remote_ssh_user = "${var.remote_ssh_user}"
}
