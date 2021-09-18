#!/bin/bash

# shellcheck disable=SC2015

set -e

CURRENT_DIR="$(dirname "$0")"
cd "$CURRENT_DIR"

source "params.sh"
source "elib.sh"

phase_prompt_pause() {
    if tty -s && [ "$PHASE_PROMPT" = "true" ]; then
        press_any_key_to_continue
    fi
}

einfo "Starting Arch Linux bootstrap process ..."

if [ ! -f "$SIDELOAD_EC2_PATH/.phase-1-done" ]; then
    einfo "Running phase 1: prepare root ..."
    phase_prompt_pause
    "$SIDELOAD_EC2_PATH/phase-1.sh"
    mkdir -p "/mnt/arch$SIDELOAD_EC2_PATH"
    cp -rf "$SIDELOAD_EC2_PATH"/* "/mnt/arch$SIDELOAD_EC2_PATH"
    touch "$SIDELOAD_EC2_PATH/.phase-1-done"
    touch "/mnt/arch$SIDELOAD_EC2_PATH/.phase-1-done"
fi

if [ ! -f "$SIDELOAD_EC2_PATH/.phase-2-done" ]; then
    einfo "Running phase 2: build root ..."
    phase_prompt_pause
    mkdir -p "/mnt/arch$SIDELOAD_EC2_PATH"
    chroot /mnt/arch bash -c "cd $SIDELOAD_EC2_PATH
                              $SIDELOAD_EC2_PATH/phase-2.sh"
    touch "$SIDELOAD_EC2_PATH/.phase-2-done"
    touch "/mnt/arch$SIDELOAD_EC2_PATH/.phase-2-done"
fi

if [ ! -f "$SIDELOAD_EC2_PATH/.phase-3-done" ]; then
    einfo "Running phase 3: switch root ..."
    phase_prompt_pause
    "$SIDELOAD_EC2_PATH/phase-3.sh"
    touch "$SIDELOAD_EC2_PATH/.phase-3-done"
    touch "/mnt/arch$SIDELOAD_EC2_PATH/.phase-3-done"

    einfo "Rebooting instance ..."
    phase_prompt_pause
    reboot
fi

if [ ! -f "$SIDELOAD_EC2_PATH/.phase-4-done" ]; then
    einfo "Running phase 4: migrate root ..."
    phase_prompt_pause
    "$SIDELOAD_EC2_PATH/phase-4.sh"
    touch "$SIDELOAD_EC2_PATH/.phase-4-done"
fi

if [ ! -f "$SIDELOAD_EC2_PATH/.phase-5-done" ]; then
    einfo "Running phase 5: create image ..."
    phase_prompt_pause
    "$SIDELOAD_EC2_PATH/phase-5.sh"
    touch "$SIDELOAD_EC2_PATH/.phase-5-done"
fi

einfo "Finalizing: kill the instance ..."
phase_prompt_pause
"$SIDELOAD_EC2_PATH/phase-6.sh"
