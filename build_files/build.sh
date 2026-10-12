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

# Latest release of a GitHub repo, taken from the /releases/latest redirect (no API, no rate limit).
# The daily build picks up new upstream releases by itself; if one can't be resolved the build
# fails before pushing, so the previously published image stays in place.
latest_version() {
    local tag
    tag=$(curl -fsSL -o /dev/null -w '%{url_effective}' "https://github.com/$1/releases/latest")
    tag=${tag##*/v}
    [[ $tag =~ ^[0-9]+(\.[0-9]+)+$ ]] || { echo "cannot resolve latest release of $1 (got '$tag')" >&2; exit 1; }
    echo "$tag"
}
# No dnf repo exists for these two: RPMs from the upstream GitHub releases
HANDY_VERSION=$(latest_version cjpais/Handy)
CRAFT_VERSION=$(latest_version storytold/craft-launcher)

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
