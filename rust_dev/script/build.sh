#!/bin/sh
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/kernel_version_to_tag.sh"
. "$SCRIPT_DIR/packages.sh"

HOST_LINUX_VERSION=$(uname -r)
KERNEL_VERSION_TAG=$(kernel_version_tag)
WORKSPACE_DIR="/home/hedaz/work"
TEMP_DIR="/tmp"
KERNEL_SOURCE_FOLDER="$TEMP_DIR/linux-$KERNEL_VERSION_TAG"
RUSTC_VERSION=""
BINDGEN_VERSION=""


install_all() {
    echo "Starting full environment deployment..."
    apt-get update
    install_system_utils
    install_c_toolchain
    install_llvm_toolchain
    install_kernel_deps

    apt-get clean
    rm -rf /var/lib/apt/lists/*
    echo "All packages installed successfully!"
}

clone_kernel() {
    TAG=$1
    git -c advice.detachedHead=false clone --depth=1 --branch "$TAG" https://github.com/torvalds/linux.git \
        "$KERNEL_SOURCE_FOLDER"
    cp /tmp/default_kconfig "$KERNEL_SOURCE_FOLDER"/.config
    RUSTC_VERSION=$(cd "$KERNEL_SOURCE_FOLDER" && ./scripts/min-tool-version.sh rustc)
    BINDGEN_VERSION=$(cd "$KERNEL_SOURCE_FOLDER" && ./scripts/min-tool-version.sh bindgen)
}

install_rustup() {
    rustc_version=$1
    bindgen_version=$2
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
        | sh -s -- -y --default-toolchain stable
    cargo install bindgen-cli --version "$bindgen_version"
    rustup toolchain install "$rustc_version"
    rustup component add rust-src --toolchain "$rustc_version"
    rustup default "$rustc_version"
}

build_kernel() {
    CLANG_IGNORE="-Wno-enum-enum-conversion"
    make -C "$KERNEL_SOURCE_FOLDER" LLVM=1 KCFLAGS="$CLANG_IGNORE" modules_prepare
    make -C "$KERNEL_SOURCE_FOLDER" LLVM=1 KCFLAGS="$CLANG_IGNORE" -j"$(nproc)" vmlinux
    make -C "$KERNEL_SOURCE_FOLDER" LLVM=1 KCFLAGS="$CLANG_IGNORE" -j"$(nproc)" modules
}

export DEBIAN_FRONTEND=noninteractive
set -eu

main() {
    install_all
    clone_kernel $KERNEL_VERSION_TAG
    install_rustup $RUSTC_VERSION $BINDGEN_VERSION
    build_kernel
}

main "$@"


