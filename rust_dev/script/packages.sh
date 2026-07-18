#!/bin/sh

update_ubuntu_source_list() {
    mkdir -p /usr/share/keyrings
    wget -qO /usr/share/keyrings/ubuntu-archive-keyring.gpg \
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

install_system_utils() {
    echo "Installing system utilities..."
    apt-get install -y \
        vim \
        curl \
        wget \
        git \
        gnupg \
        ca-certificates
}

install_c_toolchain() {
    echo "Installing C/C++ compilation toolchain..."
    apt-get install -y \
        build-essential \
        make \
        gcc-13 \
        g++-13

    ln -sf /usr/bin/gcc-13 /usr/bin/gcc
    ln -sf /usr/bin/g++-13 /usr/bin/g++
}

install_llvm_toolchain() {
    echo "Installing LLVM/Clang toolchain..."
    apt-get install -y \
        clang \
        lld \
        llvm \
        libclang-dev
}

install_kernel_deps() {
    echo "Installing kernel build dependencies..."
    apt-get install -y \
        flex \
        bison \
        bc \
        libelf-dev \
        libssl-dev
}