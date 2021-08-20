#!/bin/bash

set -e

source "params.sh"
source "elib.sh"

INSTANCE_ID=$(curl --silent --max-time 5 --fail http://169.254.169.254/latest/meta-data/instance-id)
echo "INSTANCE_ID=$INSTANCE_ID"

# check validity of parameters
eexec [ -n "$INSTANCE_ID" ]
eexec [ -n "$AWS_REGION" ]

# terminate the instance
eexec aws-curl --ec2-creds \
    --request POST \
    --fail-with-body \
    --header "Content-Type: application/x-www-form-urlencoded" \
    --data "Action=TerminateInstances" \
    --data "Version=2016-11-15" \
    --data "InstanceId.1=$INSTANCE_ID" \
    "https://ec2.$AWS_REGION.amazonaws.com"
