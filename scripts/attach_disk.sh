#!/bin/bash

set -e  # Exit on error

# Variables
disk="/dev/sdc"
vg_name="data-vg"
lv_name="data-lv"
mount_point="/data"

# Create Physical Volume
sudo pvcreate "$disk"

# Create Volume Group
sudo vgcreate "$vg_name" "$disk"

# Create Logical Volume (100% of free space)
sudo lvcreate -l 100%FREE --name "$lv_name" "$vg_name"

# Create filesystem
sudo mkfs.xfs "/dev/$vg_name/$lv_name"

# Create mount point
sudo mkdir -p "$mount_point"

# Update fstab
echo "/dev/$vg_name/$lv_name $mount_point xfs defaults 0 0" | sudo tee -a /etc/fstab

# Mount the volume
sudo mount -a

echo "LVM setup complete. $mount_point is ready to use."