#!/bin/sh
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/kernel_version_to_tag.sh"
. "$SCRIPT_DIR/packages.sh"

HOST_LINUX_VERSION=$(uname -r)
KERNEL_VERSION_TAG=$(kernel_version_tag)
WORKSPACE_DIR="/home/hedaz/work"
TEMP_DIR="/tmp"
KERNEL_SOURCE_FOLDER="$TEMP_DIR/linux-$KERNEL_VERSION_TAG"
MIN_RUSTC_VERSION=""
MIN_BINDGEN_VERSION=""

install_all() {
    echo "Starting full environment deployment..."
    apt-get update
    install_system_deps
    install_zscaler_ca
    apt-get clean
    rm -rf /var/lib/apt/lists/*
    echo "All packages installed successfully!"
}

clone_kernel() {
    TAG=$1
    git -c advice.detachedHead=false clone --depth=1 --branch "$TAG" https://github.com/torvalds/linux.git \
        "$KERNEL_SOURCE_FOLDER"
    MIN_RUSTC_VERSION=$(cd "$KERNEL_SOURCE_FOLDER" && ./scripts/min-tool-version.sh rustc)
    MIN_BINDGEN_VERSION=$(cd "$KERNEL_SOURCE_FOLDER" && ./scripts/min-tool-version.sh bindgen)
}

install_rustup() {
    local target_rustc="$1"
    local target_bindgen="$2"
    echo "Installing Rustup ecosystem..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
        | sh -s -- -y --default-toolchain stable --profile minimal

    export CARGO_HOME="$HOME/.cargo"
    export PATH="$HOME/.cargo/bin:$PATH"
    echo "Compiling bindgen-cli v${target_bindgen} via stable toolchain..."
    cargo install bindgen-cli
    echo "Installing toolchain needed for kernel: ${target_rustc}"
    rustup default 1.84.1
    rustup component add rust-src rustfmt clippy
    make -C "$KERNEL_SOURCE_FOLDER" LLVM=1 rustavailable
}

config_kernel() {
    current_folder=$(pwd)
    cd "$KERNEL_SOURCE_FOLDER"
    make LLVM=1 allnoconfig

    # 64-bit kernel
    scripts/config --enable CONFIG_64BIT

    # initramfs support & GZIP compression engine (CRITICAL FOR BOOT SUCCESS)
    scripts/config --enable CONFIG_BLK_DEV_INITRD
    scripts/config --enable CONFIG_RD_GZIP

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

    # Network
    scripts/config --enable CONFIG_INET
    scripts/config --enable CONFIG_NET

    # Rust the master switch
    scripts/config --enable CONFIG_RUST

    # Rust sample modules
    scripts/config --enable CONFIG_SAMPLES
    scripts/config --enable CONFIG_SAMPLES_RUST

    # Fix Clang toolchain compilation limits
    scripts/config --set-val FRAME_WARN 2048
    sed -i '/KBUILD_CFLAGS.*+=/a KBUILD_CFLAGS += $(call cc-disable-warning, enum-enum-conversion)' Makefile

    make LLVM=1 olddefconfig
    cd "$current_folder"
}

build_kernel() {
    make -C "$KERNEL_SOURCE_FOLDER" LLVM=1 -j"$(nproc)" all
}

build_root_filesystem() {
    current_folder=$(pwd)
    cd "$KERNEL_SOURCE_FOLDER"
    mkdir -p ./initramfs/bin ./initramfs/lib ./initramfs/dev ./initramfs/proc ./initramfs/sys ./initramfs/tmp
    cp /usr/bin/busybox ./initramfs/bin/
    cd ./initramfs/bin
    ln -s busybox sh
    ln -s busybox ls
    ln -s busybox mount
    cd "$KERNEL_SOURCE_FOLDER"

    # shfmt: skip
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
    cd "$current_folder"
}

packet_root_filesystem() {
    cd "$KERNEL_SOURCE_FOLDER/initramfs"
    find . | cpio -H newc -o | gzip > ../initramfs.cpio.gz
}

build_qemu_run() {
    # shfmt: skip
    cat <<EOF > /usr/bin/qemu_cli
#!/bin/sh
KERNEL_SOURCE_FOLDER="$KERNEL_SOURCE_FOLDER"
build() {
cd "\$KERNEL_SOURCE_FOLDER/initramfs"
find . | cpio -H newc -o \
| gzip > ../initramfs.cpio.gz
}
run() {
qemu-system-x86_64 \
-kernel "\$KERNEL_SOURCE_FOLDER/arch/x86/boot/bzImage" \
-initrd "\$KERNEL_SOURCE_FOLDER/initramfs.cpio.gz" \
-append "console=ttyS0 nokaslr" \
-nographic \
    -m 512M
}
while [ \$# -gt 0 ]; do
case "\$1" in
--build)    build; exit 0;;
--run)      run; exit 0 ;;
*)          echo "Unknown option: \$1"; exit -22 ;;
esac
done
EOF
    chmod +x /usr/bin/qemu_cli
}

export DEBIAN_FRONTEND=noninteractive
set -eu

main() {
    install_all
    clone_kernel "$KERNEL_VERSION_TAG"
    install_rustup "$MIN_RUSTC_VERSION" "$MIN_BINDGEN_VERSION"
    config_kernel
    build_kernel
    build_root_filesystem
    packet_root_filesystem
    build_qemu_run
}

main "$@"
