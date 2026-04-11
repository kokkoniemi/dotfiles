#!/bin/bash

EXPECTED_ID="fedora"

if [ -r /etc/os-release ]; then
    . /etc/os-release
fi

if [ "${ID:-}" != "$EXPECTED_ID" ] || { [ "${VERSION_ID:-}" != "42" ] && [ "${VERSION_ID:-}" != "43" ]; }; then
    echo "This script is built for Fedora 42 or 43."
    echo "Detected: ${PRETTY_NAME:-unknown OS}"
    read -p "Continue anyway? [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]] || exit 1
fi

# essentials
sudo dnf install gcc make vim vimx wireguard-tools git fzf rg terminus-fonts terminus-fonts-console

# 1password
sudo rpm --import https://downloads.1password.com/linux/keys/1password.asc
sudo sh -c 'echo -e "[1password]\nname=1Password Stable Channel\nbaseurl=https://downloads.1password.com/linux/rpm/stable/\$basearch\nenabled=1\ngpgcheck=1\nrepo_gpgcheck=1\ngpgkey=\"https://downloads.1password.com/linux/keys/1password.asc\"" > /etc/yum.repos.d/1password.repo'
sudo dnf install 1password

# OpenSnitch https://github.com/evilsocket/opensnitch/releases/tag/v1.7.2
wget --quiet -O /tmp/opensnitch.rpm https://github.com/evilsocket/opensnitch/releases/download/v1.7.2/opensnitch-1.7.2-1.x86_64.rpm
wget --quiet -O /tmp/opensnitch-ui.rpm https://github.com/evilsocket/opensnitch/releases/download/v1.7.2/opensnitch-ui-1.7.2-1.noarch.rpm
sudo dnf install /tmp/opensnitch.rpm /tmp/opensnitch-ui.rpm

# non-free media codecs
sudo dnf install \
https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

sudo dnf5 install @multimedia @sound-and-video \
--setopt=install_weak_deps=False \
--exclude=PackageKit-gstreamer-plugin

# Bashrc

TARGET="$(pwd)/.bashrc-fedora"
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
