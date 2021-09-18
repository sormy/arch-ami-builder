#!/bin/bash

# global: ELIB_VERBOSE=true|false (default: true)
# global: ELIB_COLORS=true|false|auto (default: auto)

EINFO_PREFIX=">>>"
EINFO_SUFFIX=""
EERROR_PREFIX="!!!"
EERROR_SUFFIX=""

# by default be verbose
if [ -z "$ELIB_VERBOSE" ]; then
    ELIB_VERBOSE=true
fi

# if colors configuration is unknown then try to detect it
if [ -z "$ELIB_COLORS" ] || [ "$ELIB_COLORS" = "auto" ]; then
    if [ -t 1 ]; then
        ELIB_COLORS="true"
    else
        ELIB_COLORS="false"
    fi
fi

# set colors based on tput (if terminal supports colors)
if tput colors &>/dev/null \
    && [ "$ELIB_COLORS" = "true" ]
then
    # https://linux.101hacks.com/ps1-examples/prompt-color-using-tput/
    EINFO_PREFIX="$(tput bold)$(tput setaf 2)>>>$(tput sgr0)$(tput bold)"
    EINFO_SUFFIX="$(tput sgr0)"
    EERROR_PREFIX="$(tput bold)$(tput setaf 1)!!!$(tput sgr0)$(tput bold)"
    EERROR_SUFFIX="$(tput sgr0)"
fi

# print normal message in the way it can be easily spotted in console
einfo() {
    echo "$EINFO_PREFIX" "$@" "$EINFO_SUFFIX"
}

# print error message in the way it can be easily spotted in console
eerror() {
    >&2 echo "$EERROR_PREFIX" "$@" "$EERROR_SUFFIX"
}

# same as einfo but doesn't finish message
ebegin() {
    echo -n "$EINFO_PREFIX" "$@"
}

# finalizes opened ebegin
eend() {
    echo "" "$@" "$EINFO_SUFFIX"
}

# print command in human readable form with an option to just paste in terminal and run
ecmd() {
    local cmd

    # short path if `sh -c ...` syntax is being used
    if [ "$1" = "sh" ] && [ "$2" = "-c" ]; then
        echo "$3"
        return
    fi

    local arg
    local line_count
    for arg in "$@"; do
        line_count="$(echo "$arg" | wc -l)"

        if [ "$line_count" -gt 1 ] \
            || [ "$arg" = "" ] \
            || echo "$arg" | grep -q '["`$\\[:space:]]'
        then
            cmd="$cmd \"$(echo "$arg" | sed -e 's/\(["`$\\]\)/\\\1/g')\""
        else
            cmd="$cmd $arg"
        fi
    done

    echo "${cmd:1}"
}

# quietly execute the process, ignore errors
eqexec() {
    einfo "exec: $(ecmd "$@")"
    if [ "$ELIB_VERBOSE" = "true" ]; then
        "$@" || true
    else
        "$@" > /dev/null 2>&1 || true
    fi
}

# execute the process and print details about execution
eexec() {
    einfo "exec: $(ecmd "$@")"
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
