#!/bin/bash

# find device from the list and try to resolve symlinks
find_device() {
    local list="$*"
    local dev
    for dev in $list; do
        if [ -e "$dev" ]; then
            realpath "$dev"
            return 0
        fi
    done
    return 1
}

# default boot disk where we would like to get linux installed to
find_pri_disk() {
    find_device /dev/sda /dev/xvda /dev/nvme0n1
}

# aux disk, where we temporarily stage linux before copying it ot primary disk
find_aux_disk() {
    find_device /dev/sdb /dev/xvdb /dev/nvme1n1
}

# build disk, where we keep large temporarily, like linux kernel build directory
# find_build_disk() {
#     find_device /dev/sdc /dev/xvdc /dev/nvme2n1
# }

# append partition number to device disk name
append_disk_part() {
    local dev="$1"
    local part="$2"
    if echo "$dev" | grep -q '[0-9]$'; then
        echo "${dev}p${part}"
    else
        echo "${dev}${part}"
    fi
}
