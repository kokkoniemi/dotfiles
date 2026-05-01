#!/bin/bash

if [ -r /etc/os-release ]; then
    . /etc/os-release
fi

if [ "${ID:-}" != "ubuntu" ] || [ "${VERSION_ID:-}" != "24.04" ]; then
    echo "This script is built for Ubuntu 24.04."
    echo "Detected: ${PRETTY_NAME:-unknown OS}"
    read -p "Continue anyway? [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]] || exit 1
fi

# essentials
sudo apt install gcc make vim vim-gtk3 wireguard-tools git fzf ripgrep tmux wl-clipboard

# 1password
curl -sS https://downloads.1password.com/linux/keys/1password.asc | sudo gpg --batch --yes --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/amd64 stable main' | sudo tee /etc/apt/sources.list.d/1password.list
sudo mkdir -p /etc/debsig/policies/AC2D62742012EA22/
curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol | sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol
sudo mkdir -p /usr/share/debsig/keyrings/AC2D62742012EA22
curl -sS https://downloads.1password.com/linux/keys/1password.asc | sudo gpg --batch --yes --dearmor --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg
sudo apt update && sudo apt install 1password

# OpenSnitch https://github.com/evilsocket/opensnitch/releases/tag/v1.8.0
wget --quiet -O /tmp/opensnitch.deb https://github.com/evilsocket/opensnitch/releases/download/v1.8.0/opensnitch_1.8.0-1_amd64.deb
wget --quiet -O /tmp/opensnitch-ui.deb https://github.com/evilsocket/opensnitch/releases/download/v1.8.0/python3-opensnitch-ui_1.8.0-1_all.deb
sudo apt install /tmp/opensnitch.deb /tmp/opensnitch-ui.deb
