#!/usr/bin/env bash

# Input variables are:
# num_disks - the number of extra (non-root) disks that are expected
# to be attached
# device_name - the device name for the disk of interest (/dev/xvdb,
# for example)
# mount_point - the directory where the disk is to be mounted
# label - the label to give the disk if it is necessary to create a
# file system
# fs_type - the file system type to use if it is necessary to create a
# file system

set -o nounset
set -o errexit
set -o pipefail

while [ `lsblk | grep -c " disk"` -lt ${num_disks} ]
do
    echo Waiting for disks to attach...
    sleep 5
done

# Create a file system on the EBS volume if one was not already there.
blkid -c /dev/null ${device_name} || mkfs -t ${fs_type} -L ${label} ${device_name}

# Grab the UUID of this volume
uuid=$(blkid -s UUID -o value ${device_name})

# Mount the file system
mount UUID="$uuid" ${mount_point}

# Save the mount point in fstab, so the file system is remounted if
# the instance is rebooted
echo "# ${label}" >> /etc/fstab
echo "UUID=$uuid ${mount_point} ${fs_type} defaults 0 2" >> /etc/fstab
