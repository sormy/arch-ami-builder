#!/bin/bash

# global: ELIB_VERBOSE=true|false (default: true)
# global: ELIB_COLORS=true|false|auto (default: auto)

EECHO_PREFIX=">>>"
EECHO_SUFFIX=""
EERROR_PREFIX="!!!"
EERROR_SUFFIX=""

# by default be verbose
if [ -z "$ELIB_VERBOSE" ]; then
    ELIB_VERBOSE=true
fi

# if colors configuration is unknown then try to detect it
if [ -z "$ELIB_COLORS" ] || [ "$ELIB_COLORS" = "auto" ]; then
    ELIB_COLORS=$([ -t 1 ] && echo true || echo false)
fi

# set colors based on tput (if tty is available)
if tty -s && [ "$ELIB_COLORS" = "true" ]; then
    # https://linux.101hacks.com/ps1-examples/prompt-color-using-tput/
    EECHO_PREFIX="$(tput bold)$(tput setaf 2)>>>$(tput sgr0)$(tput bold)$(tput setaf 7)"
    EECHO_SUFFIX="$(tput sgr0)"
    EERROR_PREFIX="$(tput bold)$(tput setaf 1)!!!$(tput sgr0)$(tput bold)$(tput setaf 7)"
    EERROR_SUFFIX="$(tput sgr0)"
fi

# print normal message in the way it can be easily spotted in console
eecho() {
    echo "$EECHO_PREFIX" "$@" "$EECHO_SUFFIX"
}

# print error message in the way it can be easily spotted in console
eerror() {
    >&2 echo "$EERROR_PREFIX" "$@" "$EERROR_SUFFIX"
}

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

# print command in human readable form with option to paste in terminal and run
ecmd() {
    local cmd
    local arg
    local line_count

    for arg in "$@"; do
        line_count="$(echo "$arg" | wc -l)"
        if [ "$line_count" -gt 1 ] || echo "$arg" | grep -q '["`$\\[:space:]]'; then
            cmd="$cmd \"$(echo "$arg" | sed -e 's/\(["`$\\]\)/\\\1/g')\""
        else
            cmd="$cmd $arg"
        fi
    done

    echo "${cmd:1}"
}

# quietly execute the process, ignore errors
eqexec() {
    eecho "exec: $(ecmd "$@")"
    if [ "$ELIB_VERBOSE" = "true" ]; then
        "$@" || true
    else
        "$@" > /dev/null 2>&1 || true
    fi
}

# execute the process and print details about execution
eexec() {
    eecho "exec: $(ecmd "$@")"
    local error_code=0
    local output_file
    if [ "$ELIB_VERBOSE" = "true" ]; then
        if "$@"; then
            :
        else
            error_code="$?"
            eerror "exec: \"$1\" process has failed ($error_code)"
        fi
    else
        output_file="$(mktemp)"
        if "$@" > "$output_file" 2>&1; then
            :
        else
            error_code="$?"
            eerror "exec: \"$1\" process has failed ($error_code)"
            >&2 cat "$output_file"
        fi
        rm "$output_file"
    fi
    return $error_code
}

# asks to press any key
press_any_key_to_continue() {
    read -n 1 -s -r -p $'Press any key to continue\n'
}
