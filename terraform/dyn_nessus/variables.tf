variable "bastion_public_ip" {}
variable "nessus_private_ips" { type = list(string) }
variable "nessus_activation_codes" { type = list(string) }
variable "remote_ssh_user" {}
