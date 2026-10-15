#!/bin/sh

# Godot 4.5, 4.5.1, 4.5.2 - AcceeKit 0.17.0
# Godot 4.6, 4.6.1 - AcceeKit 0.18.0
# Godot 4.6.2, 4.6.3, 4.7, 4.7.1, - AcceeKit 0.21.2
# Godot 4.7.2 - AcceeKit 0.22.3
GODOT_VERSION=4.7
GODOT_ACCESSKIT_VERSION=0.23.1
GODOT_GIT_URL=https://github.com/godotengine/godot.git
GODOT_ACCESSKIT_GIT_URL=https://github.com/AccessKit/accesskit-c.git

apt_run() {
    env DEBIAN_FRONTEND=noninteractive apt-get "$@"
}

install_essential_package() {
    apt-get update
    apt_run install -y \
    build-essential \
    scons \
    pkg-config \
    libx11-dev \
    libxcursor-dev \
    libxinerama-dev \
    libgl1-mesa-dev \
    libglu1-mesa-dev \
    libasound2-dev \
    libpulse-dev \
    libudev-dev \
    libxi-dev \
    libxrandr-dev \
    libwayland-dev \
    libfontconfig1 \
    libxkbcommon0 \
    curl \
    git \
    cmake
}

install_rustc() {
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
        | sh -s -- -y --default-toolchain stable --profile minimal

    export CARGO_HOME="$HOME/.cargo"
    export PATH="$HOME/.cargo/bin:$PATH"

    rustup toolchain install stable
    rustup default stable
}

check_python_is_supported() {
    command -v python3 >/dev/null 2>&1 &&
        python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 9) else 1)'
}

check_scons_version() {
    if ! check_python_is_supported; then
        apt_run install -y python3
        if ! check_python_is_supported; then
            echo "Error: APT did not provide Python 3.9 or newer." >&2
            exit
        fi
    fi

    if ! python3 -c '
import re
import subprocess
import sys

output = subprocess.check_output(["scons", "--version"], text=True)
match = re.search(r"SCons(?::|\s+version)\s+v?(\d+)\.(\d+)", output, re.IGNORECASE)
sys.exit(0 if match and tuple(map(int, match.groups())) >= (4, 4) else 1)
    '; then
        echo "Error: Godot requires SCons 4.4 or newer." >&2
        exit
    fi
}

install_godot() {
    git clone --depth=1 --branch $GODOT_VERSION $GODOT_GIT_URL /tmp/godot
    cd /tmp/godot
    git switch -c godot_dev
}

install_godot_accesskit() {
    git clone --depth=1 --branch $GODOT_ACCESSKIT_VERSION $GODOT_ACCESSKIT_GIT_URL /tmp/accesskit-c
    cd /tmp/accesskit-c
    git switch -c godot_dev
    cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
    cmake --build build
    cmake --install build
}

build_godot() {
    cd /tmp/godot
    scons platform=linuxbsd target=editor
}

set -eu

main() {
    install_essential_package
    install_rustc
    install_godot_accesskit
    install_godot
    build_godot
}

main "$@"
