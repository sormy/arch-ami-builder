#!/bin/bash

set -e

source "params.sh"
source "elib.sh"

AMI_NAME_PREFIX="${AMI_NAME_PREFIX:-Arch Linux $(uname -m)}"
echo "AMI_NAME_PREFIX=$AMI_NAME_PREFIX"

AMI_NAME="${AMI_NAME:-$AMI_NAME_PREFIX $(date +"%Y-%m-%d %s")}"
echo "AMI_NAME=$AMI_NAME"

INSTANCE_ID=$(curl --silent --max-time 5 --fail http://169.254.169.254/latest/meta-data/instance-id)
echo "INSTANCE_ID=$INSTANCE_ID"

# check validity of parameters
eexec [ -n "$AMI_NAME" ]
eexec [ -n "$INSTANCE_ID" ]
eexec [ -n "$AWS_REGION" ]

# unmount disk so we can safely make an image from it
eqexec pkill gpg-agent
eqexec umount /mnt/arch/dev/shm \
    /mnt/arch/dev/pts \
    /mnt/arch/dev \
    /mnt/arch/proc \
    /mnt/arch/sys \
    /mnt/arch/boot/efi \
    /mnt/arch

# TODO: May be: fsfreeze --freeze /mnt/arch && fsfreeze --unfreeze /mnt/arch ?

# if we can't unmount then remount read-only
# TODO: do we need it?
# eqexec mount -o remount,ro /mnt/arch

# even if mounted read-only, try to do lazy unmount
# TODO: do we need it?
# eqexec umount /mnt/arch -l

# install aws-curl
eexec curl -s https://raw.githubusercontent.com/sormy/aws-curl/master/aws-curl \
    -o /usr/local/bin/aws-curl
eexec chmod +x /usr/local/bin/aws-curl

# trigger image creation
eexec aws-curl --ec2-creds \
    --request POST \
    --fail-with-body \
    --header "Content-Type: application/x-www-form-urlencoded" \
    --data "Action=CreateImage" \
    --data "Version=2016-11-15" \
    --data "InstanceId=$INSTANCE_ID" \
    --data "Name=$AMI_NAME" \
    --data "Description=$AMI_NAME" \
    --data "NoReboot=true" \
    --data "BlockDeviceMapping.1.DeviceName=/dev/sdb" \
    --data "BlockDeviceMapping.1.NoDevice=" \
    "https://ec2.$AWS_REGION.amazonaws.com"

# TODO: Remove old images assuming that this request will be successfull

# TODO: run hook SIDELOAD_USER_IMAGE
