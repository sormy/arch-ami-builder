#!/bin/bash

################################################################################
# Downloads bootstrap scripts from s3 bucket and runs bootstrap process.
################################################################################

set -e

# just for reference for variables being used in this file
BOOTSTRAP_S3_PATH="s3://my-bucket/path"
BOOTSTRAP_EC2_PATH="/opt/arch-bootstrap"

if [ ! -e "$BOOTSTRAP_EC2_PATH" ]; then
    echo "Installing bootstrap files ..."
    aws s3 sync "$BOOTSTRAP_S3_PATH" "$BOOTSTRAP_EC2_PATH"
    chmod +x "$BOOTSTRAP_EC2_PATH"/bootstrap.sh "$BOOTSTRAP_EC2_PATH"/phase-*.sh
else
    echo "Waiting for boot to finish ..."
    sleep 30
fi

echo "Invoking bootstrap ..."
"$BOOTSTRAP_EC2_PATH"/bootstrap.sh
