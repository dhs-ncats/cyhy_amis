data "aws_ami" "cyhy_mongo" {
  filter {
    name = "name"
    values = [
      "cyhy-mongo-hvm-*-amd64-ebs"
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

resource "aws_instance" "cyhy_mongo" {
  ami = "${data.aws_ami.cyhy_mongo.id}"
  instance_type = "${terraform.workspace == "production" ? "m4.large" : "t2.micro"}"
  # ebs_optimized = true
  availability_zone = "${var.aws_region}${var.aws_availability_zone}"

  subnet_id = "${aws_subnet.cyhy_private_subnet.id}"
  # associate_public_ip_address = true

  root_block_device {
    volume_type = "gp2"
    volume_size = 8
    delete_on_termination = true
  }

  vpc_security_group_ids = [
    "${aws_security_group.cyhy_private_sg.id}"
  ]

  user_data = "${data.template_cloudinit_config.ssh_and_mongo_cloud_init_tasks.rendered}"

  tags = "${merge(var.tags, map("Name", "CyHy Mongo"))}"
}

# Provision the mongo EC2 instance via Ansible
module "cyhy_mongo_ansible_provisioner" {
  source = "github.com/cloudposse/tf_ansible"

  arguments = [
    "--user=${var.remote_ssh_user}",
    "--ssh-common-args='-o StrictHostKeyChecking=no -o ProxyCommand=\"ssh -W %h:%p -o StrictHostKeyChecking=no -q ${var.remote_ssh_user}@${aws_instance.cyhy_bastion.public_ip}\"'"
  ]
  envs = [
    "host=${aws_instance.cyhy_mongo.private_ip}",
    "bastion_host=${aws_instance.cyhy_bastion.public_ip}",
    "host_groups=mongo"
  ]
  playbook = "../ansible/playbook.yml"
  dry_run = false
}

# Note that the EBS volumes contain production data. Therefore we need
# these resources to be immortal in the "production" workspace, and so
# I am using the prevent_destroy lifecycle element to disallow the
# destruction of it via terraform in that case.
#
# I'd like to use "${terraform.workspace == "production" ? true :
# false}", so the prevent_destroy only applies to the production
# workspace, but it appears that interpolations are not supported
# inside of the lifecycle block
# (https://github.com/hashicorp/terraform/issues/3116).
resource "aws_ebs_volume" "cyhy_mongo_data" {
  availability_zone = "${var.aws_region}${var.aws_availability_zone}"
  type = "io1"
  size = "${terraform.workspace == "production" ? 200 : 20}"
  iops = 1000
  encrypted = true

  tags = "${merge(var.tags, map("Name", "CyHy Mongo Data"))}"

  lifecycle {
    prevent_destroy = true
  }
}
resource "aws_ebs_volume" "cyhy_mongo_journal" {
  availability_zone = "${var.aws_region}${var.aws_availability_zone}"
  type = "io1"
  size = 8
  iops = 250
  encrypted = true

  tags = "${merge(var.tags, map("Name", "CyHy Mongo Journal"))}"

  lifecycle {
    prevent_destroy = true
  }
}
resource "aws_ebs_volume" "cyhy_mongo_log" {
  availability_zone = "${var.aws_region}${var.aws_availability_zone}"
  type = "io1"
  size = 8
  iops = 100
  encrypted = true

  tags = "${merge(var.tags, map("Name", "CyHy Mongo Log"))}"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_volume_attachment" "cyhy_mongo_data_attachment" {
  device_name = "${var.mongo_disks["data"]}"
  volume_id = "${aws_ebs_volume.cyhy_mongo_data.id}"
  instance_id = "${aws_instance.cyhy_mongo.id}"

  # Terraform attempts to destroy the volume attachments before it attempts to
  # destroy the EC2 instance they are attached to.  EC2 does not like that and
  # it results in the failed destruction of the volume attachments.  To get
  # around this, we explicitly terminate the cyhy_mongo volume via the AWS CLI
  # in a destroy provisioner; this gracefully shuts down the instance and
  # allows terraform to successfully destroy the volume attachments.
  provisioner "local-exec" {
    when = "destroy"
    command = "aws --region=${var.aws_region} ec2 terminate-instances --instance-ids ${aws_instance.cyhy_mongo.id}"
    on_failure = "continue"
  }

  # Wait until cyhy_mongo instance is terminated before continuing on
  provisioner "local-exec" {
    when = "destroy"
    command = "aws --region=${var.aws_region} ec2 wait instance-terminated --instance-ids ${aws_instance.cyhy_mongo.id}"
  }

  skip_destroy = true
}

resource "aws_volume_attachment" "cyhy_mongo_journal_attachment" {
  device_name = "${var.mongo_disks["journal"]}"
  volume_id = "${aws_ebs_volume.cyhy_mongo_journal.id}"
  instance_id = "${aws_instance.cyhy_mongo.id}"

  provisioner "local-exec" {
    when = "destroy"
    command = "aws --region=${var.aws_region} ec2 terminate-instances --instance-ids ${aws_instance.cyhy_mongo.id}"
    on_failure = "continue"
  }

  # Wait until cyhy_mongo instance is terminated before continuing on
  provisioner "local-exec" {
    when = "destroy"
    command = "aws --region=${var.aws_region} ec2 wait instance-terminated --instance-ids ${aws_instance.cyhy_mongo.id}"
  }

  skip_destroy = true
}

resource "aws_volume_attachment" "cyhy_mongo_log_attachment" {
  device_name = "${var.mongo_disks["log"]}"
  volume_id = "${aws_ebs_volume.cyhy_mongo_log.id}"
  instance_id = "${aws_instance.cyhy_mongo.id}"

  provisioner "local-exec" {
    when = "destroy"
    command = "aws --region=${var.aws_region} ec2 terminate-instances --instance-ids ${aws_instance.cyhy_mongo.id}"
    on_failure = "continue"
  }

  # Wait until cyhy_mongo instance is terminated before continuing on
  provisioner "local-exec" {
    when = "destroy"
    command = "aws --region=${var.aws_region} ec2 wait instance-terminated --instance-ids ${aws_instance.cyhy_mongo.id}"
  }

  skip_destroy = true
}