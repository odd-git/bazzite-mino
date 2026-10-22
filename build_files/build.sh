#!/bin/bash

set -ouex pipefail

# Copy the contents of system_files/ of the git repo to /
cp -avf "/ctx/system_files"/. /
chmod 0440 /etc/sudoers.d/ardour-gpu /etc/sudoers.d/virtual-display

# Default wallpaper via a gschema override. Validate our file strictly on its own (bazzite's own
# overrides contain keys that --strict rejects), then compile everything the way bazzite does.
schemas=/usr/share/glib-2.0/schemas
check=$(mktemp -d)
cp "$schemas"/org.gnome.desktop.{background.gschema,enums}.xml "$schemas"/zz9-mino.gschema.override "$check"
glib-compile-schemas --strict "$check"
rm -r "$check"
glib-compile-schemas "$schemas"

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
# SoundCraft is part of the Craft suite. It ships as an RPM, not the launcher's Flatpak: the sandbox
# can't create the session's "Audio Files" folder (document portal) and its menu entry would mask this one.
SOUNDCRAFT_VERSION=$(latest_version storytold/soundcraft)

dnf5 install -y \
    liquidctl \
    torbrowser-launcher \
    "https://github.com/cjpais/Handy/releases/download/v${HANDY_VERSION}/Handy-${HANDY_VERSION}-1.x86_64.rpm" \
    "https://github.com/storytold/craft-launcher/releases/download/v${CRAFT_VERSION}/artcraft-launcher-${CRAFT_VERSION}-linux-x86_64.rpm" \
    "https://github.com/storytold/soundcraft/releases/download/v${SOUNDCRAFT_VERSION}/soundcraft-${SOUNDCRAFT_VERSION}-linux-x86_64.rpm"

# Venturi ships only as an AppImage: extract it at build time (no FUSE needed at runtime).
# The binary finds its bundled libs via RPATH $ORIGIN/../lib.
VENTURI_VERSION=$(latest_version VenturiVideo/Venturi)
venturi=$(mktemp -d)
curl -fsSL -o "$venturi/Venturi.AppImage" \
    "https://github.com/VenturiVideo/Venturi/releases/download/v${VENTURI_VERSION}/Venturi-x86_64.AppImage"
chmod +x "$venturi/Venturi.AppImage"
(cd "$venturi" && ./Venturi.AppImage --appimage-extract >/dev/null)
chmod -R u=rwX,go=rX "$venturi/squashfs-root"  # extracted dirs are 0700
mkdir -p /usr/lib/venturi
cp -a "$venturi/squashfs-root/usr/bin" "$venturi/squashfs-root/usr/lib" /usr/lib/venturi/
cp -a "$venturi/squashfs-root/usr/share"/. /usr/share/
ln -sf /usr/lib/venturi/bin/vv-app /usr/bin/vv-app
rm -r "$venturi"
update-mime-database /usr/share/mime

# Terra ships disabled in Bazzite: enable it only for this transaction.
# uwsm runs the Hyprland session: it reaches graphical-session.target (Sunshine) and runs XDG autostart.
dnf5 install -y --enablerepo=terra coolercontrol uwsm

# Hyprland, a secondary GDM session for now. Not in Fedora; sdegler's COPR (successor of solopasha's)
# tracks upstream releases. DMS (bar, launcher, notifications, lock, idle, polkit, clipboard) comes from
# its upstream COPRs; quickshell too, as Fedora's is an old git snapshot. No dms-greeter: GDM stays for now.
# includepkgs keeps everything else (kitty, cliphist, ghostty...) on Fedora's builds.
cat > /etc/yum.repos.d/hyprland.repo <<'REPO'
[copr-sdegler-hyprland]
name=Copr sdegler/hyprland
baseurl=https://download.copr.fedorainfracloud.org/results/sdegler/hyprland/fedora-$releasever-$basearch/
enabled=1
gpgcheck=1
gpgkey=https://download.copr.fedorainfracloud.org/results/sdegler/hyprland/pubkey.gpg
includepkgs=hypr*,aquamarine,glaze,xdg-desktop-portal-hyprland

[copr-avengemedia-dms]
name=Copr avengemedia/dms
baseurl=https://download.copr.fedorainfracloud.org/results/avengemedia/dms/fedora-$releasever-$basearch/
enabled=1
gpgcheck=1
gpgkey=https://download.copr.fedorainfracloud.org/results/avengemedia/dms/pubkey.gpg
includepkgs=dms,dms-cli

[copr-avengemedia-danklinux]
name=Copr avengemedia/danklinux
baseurl=https://download.copr.fedorainfracloud.org/results/avengemedia/danklinux/fedora-$releasever-$basearch/
enabled=1
gpgcheck=1
gpgkey=https://download.copr.fedorainfracloud.org/results/avengemedia/danklinux/pubkey.gpg
includepkgs=quickshell,cpptrace,dgop,danksearch,matugen
REPO
dnf5 install -y \
    hyprland hyprland-uwsm xdg-desktop-portal-hyprland dms quickshell \
    grim slurp swappy wl-clipboard brightnessctl playerctl pavucontrol kdeconnectd
rm /etc/yum.repos.d/hyprland.repo
# The COPR can lag upstream by weeks: warn only, so the rest of the image keeps updating daily.
hypr_have=$(rpm -q --qf '%{VERSION}' hyprland)
hypr_latest=$(latest_version hyprwm/Hyprland)
[[ $hypr_have == "$hypr_latest" ]] || echo "WARNING: Hyprland $hypr_have from the COPR, upstream is at $hypr_latest" >&2

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
