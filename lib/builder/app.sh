#!/bin/bash

################################################################################
# Helper functions that are not using global application state variables.
################################################################################

create_ec2_device_mapping() {
    local shapshot_id="$1"
    local volume_size="$2"
    local volume_type="${3:-gp2}"
    local keep_aux_disk="${4:-false}"

    local aux_disk_delete
    if [ "$keep_aux_disk" = "true" ]; then
        aux_disk_delete="false"
    else
        aux_disk_delete="true"
    fi

    cat <<- END
[
    {
        "DeviceName": "/dev/xvda",
        "Ebs": {
            "DeleteOnTermination": true,
            "SnapshotId": "$shapshot_id",
            "VolumeSize": $volume_size,
            "VolumeType": "$volume_type"
        }
    },{
        "DeviceName": "/dev/xvdb",
        "Ebs": {
            "DeleteOnTermination": $aux_disk_delete,
            "VolumeSize": $volume_size,
            "VolumeType": "$volume_type"
        }
    }
]
END
}

create_ec2_user_data() {
    local bootstrap_s3_path="$1"
    local bootstrap_ec2_path="$2"

    local user_data_file="lib/builder/user-data.sh"

    BOOTSTRAP_S3_PATH="$bootstrap_s3_path" \
    BOOTSTRAP_EC2_PATH="$bootstrap_ec2_path" \
        envsubst < "$user_data_file"
}

print_bootstrap_params() {
    local src_param_file="lib/bootstrap/params.sh"
    envsubst < "$src_param_file" | grep -v '^#' | grep -v '^$'
}

sideload_bootstrap_scripts_s3() {
    local sideload_s3_path="$1"

    local src_bootstrap_dir="lib/bootstrap"
    local src_param_file="lib/bootstrap/params.sh"

    local temp_params_file
    temp_params_file="$(mktemp)"
    envsubst < "$src_param_file" > "$temp_params_file"

    aws s3 sync --region "$AWS_REGION" "$src_bootstrap_dir" "$sideload_s3_path"

    aws s3 cp --region "$AWS_REGION" "$temp_params_file" \
        "$sideload_s3_path/$(basename "$src_param_file")"

    rm -f "$temp_params_file"
}

sideload_bootstrap_scripts_ssh() {
    local sideload_path="$1"
    local sideload_target="$2"
    local sideload_clean="${3:-false}"

    # clean target if enabled
    if [ "$sideload_clean" = "true" ]; then
        ssh $SSH_OPTS "$sideload_target" "sudo sh -c 'rm -rf $sideload_path'"
    fi

    # creating a directory and fixing permissions
    ssh $SSH_OPTS "$sideload_target" \
        "sudo sh -c 'mkdir -p $sideload_path; chmod -R a+rwX $sideload_path;'"

    # copying bootstrap scripts
    scp $SSH_OPTS lib/bootstrap/* "$sideload_target:$sideload_path"

    # making bootstrap scripts executable
    ssh $SSH_OPTS "$sideload_target" \
        "sudo chmod +x $sideload_path/bootstrap.sh $sideload_path/phase-*.sh"

    # copying params
    local temp_param_file
    temp_param_file="$(mktemp)"
    envsubst < lib/bootstrap/params.sh > "$temp_param_file"
    scp $SSH_OPTS "$temp_param_file" "$sideload_target:$sideload_path/params.sh"
    rm -f "$temp_param_file"
}

wait_for() {
    local cmd="$1"
    local interval="$2"
    local max_attempts="$3"

    local attempt=0

    local temp_error_file
    temp_error_file="$(mktemp)"

    while : ; do
        attempt=$(( attempt + 1 ))

        if [ -n "$max_attempts" ]; then
            echo "Attempt $attempt from $max_attempts ..."
        else
            echo "Attempt $attempt ..."
        fi

        if eval "$cmd" >"$temp_error_file" 2>&1; then
            rm -f "$temp_error_file"
            return 0
        fi

        if [ -n "$max_attempts" ] \
            && [ "$attempt" = "$max_attempts" ]
        then
            >&2 cat "$temp_error_file"
            rm -f "$temp_error_file"
            return 1
        fi

        sleep "$interval"
    done
}

wait_until_ssh_will_be_up() {
    local target="$1"
    local interval="${2:-60}"
    local max_attempts="${3:-3}"

    wait_for "ssh $SSH_OPTS \"$target\" \"exit\"" \
        "$interval" "$max_attempts"
}

wait_until_instance_will_be_up() {
    local instance_id="$1"
    local interval="${2:-60}"
    local max_attempts="${3:-3}"

    wait_for "[ \"\$(aws_ec2_instance_state \"$instance_id\")\" = \"running\" ]" \
        "$interval" "$max_attempts"
}
