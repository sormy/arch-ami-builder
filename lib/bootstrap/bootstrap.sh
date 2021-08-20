#!/bin/bash

# shellcheck disable=SC2015

set -e

CURRENT_DIR="$(dirname "$0")"
cd "$CURRENT_DIR"

source "params.sh"
source "elib.sh"

SIDELOAD_MODE="${1:-ssh}" # ssh | ec2-init

phase_prompt_pause() {
    if tty -s && [ "$PHASE_PROMPT" = "true" ]; then
        press_any_key_to_continue
    fi
}

eecho "Starting Arch Linux bootstrap process (over $SIDELOAD_MODE) ..."

if [ ! -f /opt/arch-bootstrap/.phase-1-done ]; then
    eecho "Running phase 1: prepare root ..."
    phase_prompt_pause
    /opt/arch-bootstrap/phase-1.sh
    mkdir -p /mnt/arch/opt/arch-bootstrap
    cp -rf /opt/arch-bootstrap/* /mnt/arch/opt/arch-bootstrap
    touch /opt/arch-bootstrap/.phase-1-done
    touch /mnt/arch/opt/arch-bootstrap/.phase-1-done
fi

if [ ! -f /opt/arch-bootstrap/.phase-2-done ]; then
    eecho "Running phase 2: build root ..."
    phase_prompt_pause
    mkdir -p /mnt/arch/opt/arch-bootstrap
    chroot /mnt/arch bash -c "cd /opt/arch-bootstrap
                              /opt/arch-bootstrap/phase-2.sh"
    touch /opt/arch-bootstrap/.phase-2-done
    touch /mnt/arch/opt/arch-bootstrap/.phase-2-done
fi

if [ ! -f /opt/arch-bootstrap/.phase-3-done ]; then
    eecho "Running phase 3: switch root ..."
    phase_prompt_pause
    /opt/arch-bootstrap/phase-3.sh
    touch /opt/arch-bootstrap/.phase-3-done
    touch /mnt/arch/opt/arch-bootstrap/.phase-3-done

    eecho "Rebooting instance ..."
    phase_prompt_pause
    reboot
fi

if [ ! -f /opt/arch-bootstrap/.phase-4-done ]; then
    eecho "Running phase 4: migrate root ..."
    phase_prompt_pause
    /opt/arch-bootstrap/phase-4.sh
    touch /opt/arch-bootstrap/.phase-4-done
fi

if [ ! -f /opt/arch-bootstrap/.phase-5-done ]; then
    eecho "Running phase 5: create image ..."
    phase_prompt_pause
    /opt/arch-bootstrap/phase-5.sh
    touch /opt/arch-bootstrap/.phase-5-done
fi

eecho "Finalizing: kill the instance ..."
phase_prompt_pause
/opt/arch-bootstrap/phase-6.sh
