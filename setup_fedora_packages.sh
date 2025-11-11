#!/bin/bash

# essentials
sudo dnf install gcc make vim vimx wireguard-tools git fzf rg

# 1password
sudo rpm --import https://downloads.1password.com/linux/keys/1password.asc
sudo sh -c 'echo -e "[1password]\nname=1Password Stable Channel\nbaseurl=https://downloads.1password.com/linux/rpm/stable/\$basearch\nenabled=1\ngpgcheck=1\nrepo_gpgcheck=1\ngpgkey=\"https://downloads.1password.com/linux/keys/1password.asc\"" > /etc/yum.repos.d/1password.repo'
sudo dnf install 1password

# OpenSnitch https://github.com/evilsocket/opensnitch/releases/tag/v1.7.2
wget --quiet -O /tmp/opensnitch.rpm https://github.com/evilsocket/opensnitch/releases/download/v1.7.2/opensnitch-1.7.2-1.x86_64.rpm
wget --quiet -O /tmp/opensnitch-ui.rpm https://github.com/evilsocket/opensnitch/releases/download/v1.7.2/opensnitch-ui-1.7.2-1.noarch.rpm
sudo dnf install /tmp/opensnitch.rpm /tmp/opensnitch-ui.rpm

