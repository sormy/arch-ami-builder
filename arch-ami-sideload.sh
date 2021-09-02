#!/bin/bash

# sideload configuration
SIDELOAD_TARGET="$1"
SIDELOAD_PATH="${SIDELOAD_PATH:-/opt/arch-bootstrap}"
SIDELOAD_CLEAN="${SIDELOAD_CLEAN:-false}"

# bootstrap configuration
export AWS_REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"
export PHASE_PROMPT="${PHASE_PROMPT:-false}"
export ELIB_VERBOSE="${ELIB_VERBOSE:-true}"
export ELIB_COLORS="${ELIB_COLORS:-true}"

# help screen
if [ -z "$SIDELOAD_TARGET" ]; then
    >&2 echo "usage: $(basename "$0") <ec2-user@hostname>"
    >&2 echo "  sideload env: SIDELOAD_PATH (default $SIDELOAD_PATH)"
    >&2 echo "  sideload env: SIDELOAD_CLEAN (default $SIDELOAD_CLEAN)"
    >&2 echo "  bootstrap env: AWS_REGION (default $AWS_REGION)"
    >&2 echo "  bootstrap env: PHASE_PROMPT (default $PHASE_PROMPT)"
    >&2 echo "  bootstrap env: ELIB_VERBOSE (default $ELIB_VERBOSE)"
    >&2 echo "  bootstrap env: ELIB_COLORS (default $ELIB_COLORS)"
    >&2 echo "  see more details in lib/bootstrap/params.sh"
    exit 1
fi

echo "Sideloading files to $SIDELOAD_TARGET:$SIDELOAD_PATH ..."
echo

# cleaning if enabled
if [ "$SIDELOAD_CLEAN" = "true" ]; then
    ssh "$SIDELOAD_TARGET" "sudo sh -c 'rm -rf $SIDELOAD_PATH'"
fi

# creating a directory and fixing permissions
ssh "$SIDELOAD_TARGET" "sudo sh -c 'mkdir -p $SIDELOAD_PATH; chmod -R a+rwX $SIDELOAD_PATH;'"

# copying bootstrap scripts
scp lib/bootstrap/* "$SIDELOAD_TARGET:$SIDELOAD_PATH"

# making bootstrap scripts executable
ssh "$SIDELOAD_TARGET" "sudo chmod +x $SIDELOAD_PATH/bootstrap.sh $SIDELOAD_PATH/phase-*.sh"

# copying params
TEMP_PARAM_FILE="$(mktemp)"
envsubst < lib/bootstrap/params.sh > "$TEMP_PARAM_FILE"
scp "$TEMP_PARAM_FILE" "$SIDELOAD_TARGET:$SIDELOAD_PATH/params.sh"
rm -f "$TEMP_PARAM_FILE"

echo
echo "Sideloading is completed."
echo
echo "Ensure:"
echo "1. Correct AWS_REGION environment variable is set."
echo "2. Instance security group allows incoming connections on 22 port"
echo "3. Instance security group allows outgoing connections to internet"
echo "4. Instance has key pair attached that you have access to locally"
echo "5. Instance is connected to public internet and has public IP address"
echo "6. Instance has attached IAM policy with these permissions:"
cat lib/config/ec2-policy.json
echo
echo "Invoke bootstrap before reboot (before phase 3):"
echo "  ssh -t ec2-user@${SIDELOAD_TARGET/*@/} sudo $SIDELOAD_PATH/bootstrap.sh"
echo
echo "Invoke bootstrap after reboot (after phase 3):"
echo "  ssh -t alarm@${SIDELOAD_TARGET/*@/} sudo $SIDELOAD_PATH/bootstrap.sh"
echo
