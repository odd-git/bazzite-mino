#!/bin/bash

set -ouex pipefail

# Copy the contents of system_files/ of the git repo to /
cp -avf "/ctx/system_files"/. /
chmod 0440 /etc/sudoers.d/ardour-gpu /etc/sudoers.d/virtual-display

### Signature policy: let rpm-ostree verify this image with cosign.pub (bazzite's policy.json only knows ublue-os)
jq '.transports.docker["ghcr.io/odd-git"] = [{"type": "sigstoreSigned", "keyPath": "/etc/pki/containers/odd-git.pub", "signedIdentity": {"type": "matchRepository"}}]' \
    /etc/containers/policy.json > /tmp/policy.json
mv /tmp/policy.json /etc/containers/policy.json
chmod 0644 /etc/containers/policy.json

### Packages

# Bump to update Handy (no dnf repo upstream: https://github.com/cjpais/Handy/releases)
HANDY_VERSION=0.9.8
# Bump to update Craft Launcher (https://github.com/storytold/craft-launcher/releases)
CRAFT_VERSION=0.2.1

dnf5 install -y \
    liquidctl \
    torbrowser-launcher \
    "https://github.com/cjpais/Handy/releases/download/v${HANDY_VERSION}/Handy-${HANDY_VERSION}-1.x86_64.rpm" \
    "https://github.com/storytold/craft-launcher/releases/download/v${CRAFT_VERSION}/artcraft-launcher-${CRAFT_VERSION}-linux-x86_64.rpm"

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
