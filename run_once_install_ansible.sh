#!/bin/bash
set -euo pipefail

install_on_arch() {
    echo "Detected Arch-based system (pacman)"

    if command -v ansible >/dev/null 2>&1; then
        echo "Ansible already installed, skipping"
        return
    fi

    echo "Installing Ansible..."
    sudo pacman -Sy --noconfirm ansible

    echo "Ansible installation complete."
}

detect_distro_and_install() {
    if command -v pacman >/dev/null 2>&1; then
        install_on_arch
    else
        echo "Unsupported Linux distribution (no pacman found)"
        exit 1
    fi
}

detect_distro_and_install
