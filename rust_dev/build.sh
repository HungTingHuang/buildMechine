#!/bin/sh
set -eu

HOST_LINUX_VERSION=$(uname -r)
echo "VERSION: $HOST_LINUX_VERSION"

export DEBIAN_FRONTEND=noninteractive

update_ubuntu_source_list() {
    wget -P /usr/share/keyrings/ \
        "http://tw.archive.ubuntu.com/ubuntu/project/ubuntu-archive-keyring.gpg"

    cat <<'EOF' > /etc/apt/sources.list.d/ubuntu.sources
Types: deb
URIs: http://tw.archive.ubuntu.com/ubuntu/
Suites: noble noble-updates noble-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: http://security.ubuntu.com/ubuntu/
Suites: noble-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF
}

install_packages() {
    apt-get update
    apt-get install -y \
        vim \
        build-essential \
        "linux-headers-$HOST_LINUX_VERSION"
}

main() {
    update_ubuntu_source_list
    install_packages
}

main "$@"


