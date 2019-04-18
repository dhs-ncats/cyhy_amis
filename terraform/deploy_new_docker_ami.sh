#!/usr/bin/env bash

# deploy_new_docker_ami.sh
# deploy_new_docker_ami.sh workspace_name

set -o nounset
set -o errexit
set -o pipefail

workspace=prod-a
if [ $# -ge 1 ]
then
    workspace=$1
fi

terraform workspace select "$workspace"

docker_instance_id=$(terraform state show aws_instance.bod_docker | \
                         grep "^id" | sed "s/^id *= \(.*\)/\1/")

# Terminate the existing docker instance
aws ec2 terminate-instances --instance-ids "$docker_instance_id"
aws ec2 wait instance-terminated --instance-ids "$docker_instance_id"

terraform apply -var-file="$workspace.tfvars" \
          -target=aws_instance.bod_docker \
          -target=aws_route53_record.bod_docker_A \
          -target=aws_route53_record.bod_rev_docker_PTR \
          -target=aws_volume_attachment.bod_report_data_attachment \
          -target=module.bod_docker_ansible_provisioner