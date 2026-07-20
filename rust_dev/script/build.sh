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
    install_system_deps

    apt-get clean
    rm -rf /var/lib/apt/lists/*
    echo "All packages installed successfully!"
}

clone_kernel() {
    TAG=$1
    git -c advice.detachedHead=false clone --depth=1 --branch "$TAG" https://github.com/torvalds/linux.git \
        "$KERNEL_SOURCE_FOLDER"
    RUSTC_VERSION=$(cd "$KERNEL_SOURCE_FOLDER" && ./scripts/min-tool-version.sh rustc)
    BINDGEN_VERSION=$(cd "$KERNEL_SOURCE_FOLDER" && ./scripts/min-tool-version.sh bindgen)
}

install_rustup() {
    rustc_version=$1
    bindgen_version=$2
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
        | sh -s -- -y --default-toolchain stable

    export CARGO_HOME="$HOME/.cargo"
    export PATH="$HOME/.cargo/bin:$PATH"

    cargo install bindgen-cli
    rustup default 1.84.1
    rustup component add rust-src rustfmt clippy
    make -C "$KERNEL_SOURCE_FOLDER" LLVM=1 rustavailable
}

config_kernel() {
    currect_folder=$(pwd)
    cd "$KERNEL_SOURCE_FOLDER"
    make LLVM=1 allnoconfig
    # 64-bit kernel
    scripts/config --enable CONFIG_64BIT
    # initramfs support
    scripts/config --enable CONFIG_BLK_DEV_INITRD
    # devtmpfs auto-populates /dev before userspace starts
    scripts/config --enable CONFIG_DEVTMPFS
    scripts/config --enable CONFIG_DEVTMPFS_MOUNT
    # Serial console required to see output with -nographic in QEMU
    scripts/config --enable CONFIG_TTY
    scripts/config --enable CONFIG_SERIAL_8250
    scripts/config --enable CONFIG_SERIAL_8250_CONSOLE
    # Binary format support without these the kernel cannot execute ANY program
    scripts/config --enable CONFIG_BINFMT_ELF
    scripts/config --enable CONFIG_BINFMT_SCRIPT
    # Loadable module support
    scripts/config --enable CONFIG_MODULES
    scripts/config --enable CONFIG_MODULE_UNLOAD
    # printk required for pr_info! and all Rust print macros
    scripts/config --enable CONFIG_PRINTK
    # Rust the master switch
    scripts/config --enable CONFIG_RUST
    # Rust sample modules
    scripts/config --enable CONFIG_SAMPLES
    scripts/config --enable CONFIG_SAMPLES_RUST
    make LLVM=1 olddefconfig
    cd "$currect_folder"
}

build_kernel() {
    make -C "$KERNEL_SOURCE_FOLDER" LLVM=1 -j"$(nproc)" all
}

build_root_filesystem() {
    currect_folder=$(pwd)
    cd "$KERNEL_SOURCE_FOLDER"
    mkdir -p ./initramfs/bin ./initramfs/sbin ./initramfs/dev ./initramfs/proc ./initramfs/sys ./initramfs/tmp
    cp /usr/bin/busybox ./initramfs/bin/
    cd ./initramfs/bin
    ln -s busybox sh
    ln -s busybox ls
    ln -s busybox mount
    cd "$KERNEL_SOURCE_FOLDER"
    cat <<'EOF' > ./initramfs/init
#!/bin/sh
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev
echo "=== Rust Kernel Boot Success ==="
echo "Kernel: $(uname -r)"
exec /bin/sh
EOF
    chmod +x ./initramfs/init
    cd ./initramfs
    find . | cpio -H newc -o | gzip > ../initramfs.cpio.gz
    cd "$currect_folder"
}

build_qemu_run() {
    cat <<'EOF' > /usr/bin/qemu_run
#!/bin/sh
qemu-system-x86_64 \
  -kernel ~/kernel-dev/linux/arch/x86/boot/bzImage \
  -initrd ~/kernel-dev/initramfs.cpio.gz \
  -append "console=ttyS0 nokaslr" \
  -nographic \
  -m 512M
EOF
    chmod +x /usr/bin/qemu_run
}

export DEBIAN_FRONTEND=noninteractive
set -eu

main() {
    install_all
    clone_kernel $KERNEL_VERSION_TAG
    install_rustup $RUSTC_VERSION $BINDGEN_VERSION
    config_kernel
    build_kernel
    build_root_filesystem
    build_qemu_run
}

main "$@"


