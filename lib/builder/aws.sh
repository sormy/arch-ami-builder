#!/bin/bash

################################################################################
# AWS helper functions.
################################################################################

##
# Check if specific IAM role exists.
##
# role_name - role name
##
aws_iam_role_exists() {
    local role_name="$1"

    ! aws iam get-role \
        --region "$AWS_REGION" \
        --role-name "$role_name" 2>&1 \
        | grep -q '(NoSuchEntity)'
}

##
# Delete IAM role.
##
# role_name - role name
##
aws_iam_delete_role() {
    local role_name="$1"

    aws iam delete-role-policy \
        --region "$AWS_REGION" \
        --role-name "$role_name" \
        --policy-name "inline" >/dev/null \
    && \
    aws iam delete-role \
        --region "$AWS_REGION" \
        --role-name "$role_name" >/dev/null
}

##
# Create IAM role.
##
# role_name - role name
# assume_role_policy - assume role policy document
# inline_role_policy - inline role policy document
##
aws_iam_create_role() {
    local role_name="$1"
    local assume_role_policy="$2"
    local inline_role_policy="$3"

    aws iam create-role \
        --region "$AWS_REGION" \
        --role-name "$role_name" \
        --assume-role-policy-document "$assume_role_policy" >/dev/null \
    && \
    aws iam put-role-policy \
        --region "$AWS_REGION" \
        --role-name "$role_name" \
        --policy-name "inline" \
        --policy-document "$inline_role_policy" >/dev/null
}

##
# Check if specific IAM instance profile exists.
##
# instance_profile_name - instance profile name
##
aws_iam_instance_profile_exists() {
    local instance_profile_name="$1"

    ! aws iam get-instance-profile \
        --region "$AWS_REGION" \
        --instance-profile-name "$instance_profile_name" 2>&1 \
        | grep -q '(NoSuchEntity)'
}

##
# Delete IAM instance profile.
##
# instance_profile_name - instance profile name
# role_name - name of the role that was attached to instance profile
##
aws_iam_delete_instance_profile() {
    local instance_profile_name="$1"
    local role_name="$2"

    aws iam remove-role-from-instance-profile \
        --region "$AWS_REGION" \
        --instance-profile-name "$instance_profile_name" \
        --role-name "$role_name" >/dev/null \
    && \
    aws iam delete-instance-profile \
        --region "$AWS_REGION" \
        --instance-profile-name "$instance_profile_name" >/dev/null
}

##
# Create instance profile and attach role to it.
##
# instance_profile_name - instance profile name
# role_name - name of the role to attach to instance profile
##
aws_iam_create_instance_profile() {
    local instance_profile_name="$1"
    local role_name="$2"

    aws iam create-instance-profile \
        --region "$AWS_REGION" \
        --instance-profile-name "$instance_profile_name" >/dev/null \
    && \
    aws iam add-role-to-instance-profile \
        --region "$AWS_REGION" \
        --instance-profile-name "$instance_profile_name" \
        --role-name "$role_name" >/dev/null
}

##
# Check if specific security group exists.
##
# sg_name - security group name
##
aws_ec2_security_group_exists() {
    local sg_name="$1"

    ! aws ec2 describe-security-groups \
        --region "$AWS_REGION" \
        --group-names "$sg_name" 2>&1 \
        | grep -q '(InvalidGroup.NotFound)'
}

##
# Delete security group.
##
# sg_name - security group name
##
aws_ec2_delete_security_group() {
    local sg_name="$1"

    aws ec2 delete-security-group \
        --region "$AWS_REGION" \
        --group-name "$sg_name" >/dev/null
}

##
# Create new security group with all egress allowed and custom ingress port rules.
##
# sg_name - security group name (and description as well)
# ingress_ports - allowed ingress ports
#   0 - no ingress allowed
#   -1 - all ports, all protocols
#   "n1 n2" - enable specific tcp ports n1 and n2
##
aws_ec2_create_security_group() {
    local sg_name="$1"
    local ingress_ports="${2:-0}"

    local sg_id
    local port

    sg_id=$(aws ec2 create-security-group \
            --region "$AWS_REGION" \
            --group-name "$sg_name" \
            --description "$sg_name" \
            --query GroupId --output text)

    if [ "$ingress_ports" != 0 ]; then
        if [ "$ingress_ports" = -1 ]; then
            aws ec2 authorize-security-group-ingress \
                --region "$AWS_REGION" \
                --group-id "$sg_id" \
                --ip-permissions IpProtocol=-1,IpRanges='[{CidrIp=0.0.0.0/0}]' \
                >/dev/null
        else
            for port in $ingress_ports; do
                aws ec2 authorize-security-group-ingress \
                    --region "$AWS_REGION" \
                    --group-id "$sg_id" \
                    --ip-permissions IpProtocol=tcp,FromPort="$port",ToPort="$port",IpRanges='[{CidrIp=0.0.0.0/0}]' \
                    >/dev/null
            done
        fi
    fi
}

##
# Run new EC2 instance.
##
# arguments - passed as it is to `aws ec2 run-instances`
##
aws_ec2_run_instance() {
    aws ec2 run-instances \
        --region "$AWS_REGION" \
        "$@" \
        --query 'Instances[0].InstanceId' \
        --output text
}

##
# Get EC2 instance public IP address.
##
# instance_id - EC2 instance ID
##
aws_ec2_instance_public_ip() {
    local instance_id="$1"

    aws ec2 describe-instances \
        --region "$AWS_REGION" \
        --instance-ids "$instance_id" \
        --query 'Reservations[0].Instances[0].NetworkInterfaces[0].Association.PublicIp' \
        --output text
}

##
# Terminate EC2 instance.
##
# instance_id - EC2 instance ID
##
aws_ec2_terminate_instance() {
    local instance_id="$1"

    aws ec2 terminate-instances \
        --region "$AWS_REGION" \
        --instance-ids "$instance_id"
}

##
# Get EC2 instance state.
##
# instance_id - EC2 instance ID
##
aws_ec2_instance_state() {
    local instance_id="$1"

    aws ec2 describe-instances \
        --region "$AWS_REGION" \
        --instance-ids "$instance_id" \
        --query 'Reservations[0].Instances[0].State.Name' \
        --output text
}

##
# Get latest amzn2 AMI image ID for specific architecture
##
# arch - amd64 | arm64 | x86
##
aws_ec2_amzn2_image_id() {
    local arch="$1" # amd64 | arm64 | x86

    local image_id
    image_id=$(aws ec2 describe-images \
        --region "$AWS_REGION" \
        --filters "Name=owner-alias,Values=amazon" \
                  "Name=name,Values=amzn2-ami-hvm-2.0.*-$arch-gp2" \
        --query "reverse(sort_by(Images, &CreationDate))[0].ImageId" \
        --output text)

    if [ "$image_id" = "None" ] || [ -z "$image_id" ]; then
        >&2 echo "Unable to find Amazon Linux 2 AMI for EC2 architecture $arch"
        return 1
    fi

    echo "$image_id"
}

##
# Get snapshot id for specific AMI image ID.
##
# image_id - AMI image ID.
##
aws_ec2_image_snapshot_id() {
    local image_id="$1"

    local snapshot_id
    snapshot_id=$(aws ec2 describe-images \
        --region "$AWS_REGION" \
        --image-ids "$image_id" \
        --query "Images[0].BlockDeviceMappings[0].Ebs.SnapshotId" \
        --output text)

    if [ "$snapshot_id" = "None" ] || [ -z "$snapshot_id" ]; then
        >&2 echo "Unable to find root volume snapshot ID for AMI $image_id"
        return 1
    fi

    echo "$snapshot_id"
}

##
# Check if s3 bucket exists.
##
# bucket_name - s3 bucket name
##
aws_s3_bucket_exists() {
    local bucket_name="$1"

    local count
    count=$(aws s3api list-buckets \
            --region "$AWS_REGION" \
            --query "Buckets[?Name == \`$bucket_name\`] | length(@)")

    [ "$count" = 1 ]
}

##
# Create s3 bucket.
##
# bucket_name - s3 bucket name
##
aws_s3_create_bucket() {
    local bucket_name="$1"

    aws s3api create-bucket \
        --region "$AWS_REGION" \
        --bucket "$bucket_name" >/dev/null \
    && \
    aws s3api put-public-access-block \
        --region "$AWS_REGION" \
        --bucket "$bucket_name" \
        --public-access-block-configuration \
            "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
        >/dev/null
}

##
# Extract s3 bucket name from s3 path.
##
# s3_path - s3 path like s3://my-bucket/my-path
##
aws_s3_bucket_name() {
    local s3_path="$1"
    echo "$s3_path" | sed -e 's!^s3://!!' -e 's!/.*$!!'
}

##
# Get caller's AWS account number.
##
aws_sts_caller_account() {
    aws sts get-caller-identity --query "Account" --output text
}
