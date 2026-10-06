#!/bin/bash

set -ouex pipefail

# Copy the contents of system_files/ of the git repo to /
cp -avf "/ctx/system_files"/. /
chmod 0440 /etc/sudoers.d/ardour-gpu /etc/sudoers.d/virtual-display

### Packages

# Bump to update Handy (no dnf repo upstream: https://github.com/cjpais/Handy/releases)
HANDY_VERSION=0.9.8

dnf5 install -y \
    liquidctl \
    torbrowser-launcher \
    "https://github.com/cjpais/Handy/releases/download/v${HANDY_VERSION}/Handy-${HANDY_VERSION}-1.x86_64.rpm"

# Terra ships disabled in Bazzite: enable it only for this transaction
dnf5 install -y --enablerepo=terra coolercontrol

# Trivalent from secureblue; repo removed afterwards, the daily build keeps it updated
cat > /etc/yum.repos.d/secureblue.repo <<'REPO'
[secureblue]
name=secureblue
baseurl=https://repo.secureblue.dev
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://repo.secureblue.dev/secureblue.gpg
REPO
dnf5 install -y trivalent
rm /etc/yum.repos.d/secureblue.repo

### Services

systemctl enable coolercontrold.service lactd.service tailscaled.service amdgpu-mclk-audiofix.service
