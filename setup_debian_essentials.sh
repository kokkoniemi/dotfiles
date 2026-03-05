#!/bin/bash

# essentials
sudo apt install gcc make vim vim-gtk3 wireguard-tools git fzf ripgrep

# 1password
curl -sS https://downloads.1password.com/linux/keys/1password.asc | sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/amd64 stable main' | sudo tee /etc/apt/sources.list.d/1password.list
sudo mkdir -p /etc/debsig/policies/AC2D62742012EA22/
	curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol | sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol
	sudo mkdir -p /usr/share/debsig/keyrings/AC2D62742012EA22
	curl -sS https://downloads.1password.com/linux/keys/1password.asc | sudo gpg --dearmor --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg
sudo apt update && sudo apt install 1password

# OpenSnitch https://github.com/evilsocket/opensnitch/releases/tag/v1.8.0
wget --quiet -O /tmp/opensnitch.deb https://github.com/evilsocket/opensnitch/releases/download/v1.8.0/opensnitch_1.8.0-1_amd64.deb
wget --quiet -O /tmp/opensnitch-ui.deb https://github.com/evilsocket/opensnitch/releases/download/v1.8.0/python3-opensnitch-ui_1.8.0-1_all.deb
sudo apt install /tmp/opensnitch.deb /tmp/opensnitch-ui.deb

# non-free media codecs
sudo apt install ffmpeg \
gstreamer1.0-plugins-{good,bad,ugly} \
gstreamer1.0-libav

# Bashrc

TARGET="$(pwd)/.bashrc-debian"
LINK="$HOME/.bashrc"

if [ -L "$LINK" ]; then
    # It's a symlink — check where it points
    [ "$(readlink -f "$LINK")" = "$TARGET" ] && echo "Symlink already correct." || {
        read -p "~/.bashrc points elsewhere. Replace with link to $TARGET? [y/N] " ans
        [[ "$ans" =~ ^[Yy]$ ]] && ln -sf "$TARGET" "$LINK" && echo "Symlink updated."
    }
elif [ -e "$LINK" ]; then
    read -p "~/.bashrc exists (not a symlink). Replace with link to $TARGET? [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]] && mv "$LINK" "$LINK.backup" && ln -s "$TARGET" "$LINK" && echo "Backup created and symlink made."
else
    ln -s "$TARGET" "$LINK"
    echo "Symlink created: $LINK → $TARGET"
fi

