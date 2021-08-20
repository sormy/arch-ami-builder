#!/bin/bash

# shellcheck disable=SC2034,SC2269

# NOTE: provisioning script will substitute variables

# An AWS region where EC2 is launched and where image should be created.
# Default is us-east-1.
# Constraints: valid AWS region name like: us-east-1, eu-west-1 etc
AWS_REGION="$AWS_REGION"

# A name prefix for the new image.
# Optional, default is Arch Linux {arch}
# Constraints: 3-100 alphanumeric characters, parentheses (()), square brackets ([]), spaces ( ), periods (.), slashes (/), dashes (-), single quotes ('), at-signs (@), or underscores(_)
AMI_NAME_PREFIX="$AMI_NAME_PREFIX"

# A name for the new image.
# Optional, default is {API_NAME_PREFIX} {YYYY-MM-DD} {timestamp}.
# Constraints: 3-128 alphanumeric characters, parentheses (()), square brackets ([]), spaces ( ), periods (.), slashes (/), dashes (-), single quotes ('), at-signs (@), or underscores(_)
AMI_NAME="$AMI_NAME"

# Wait for key press before invoking every phase.
# For debugging purposes only. Disabled by default.
# Constraints: true | false
PHASE_PROMPT="$PHASE_PROMPT"

# If verbose then will show output of every executed command, otherwise
# output wil be displayed only if command has failed. Enabled by default.
# Constraints: true | false
ELIB_VERBOSE="$ELIB_VERBOSE"

# Use colors in shell output.
# Default value is "auto" - it tries to detect if shell supports colors.
# Constraints: true | false | auto
ELIB_COLORS="$ELIB_COLORS"
