#!/bin/sh

# Convert the host kernel version like 6.8.0-52-generic
# into the upstream Linux tag format such as v6.8.
#
# This script is meant to be sourced by build.sh:
#   . "$SCRIPT_DIR/kernel_version_to_tag.sh"
#   KERNEL_VERSION_TAG=$(kernel_version_tag)

kernel_version_tag() {
    host_version=${HOST_LINUX_VERSION:-$(uname -r)}
    kernel_version=${host_version%%-*}

    major=$(printf '%s' "$kernel_version" | cut -d. -f1)
    minor=$(printf '%s' "$kernel_version" | cut -d. -f2)

    if [ -n "$major" ] && [ -n "$minor" ]; then
        printf 'v%s.%s\n' "$major" "$minor"
    else
        printf 'v%s\n' "$kernel_version"
    fi
}
