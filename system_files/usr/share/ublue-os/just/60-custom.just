# Restore user-level apps on a fresh install: Flatpaks and Homebrew
mino-restore:
    #!/usr/bin/bash
    set -euo pipefail
    flatpak install -y --noninteractive flathub $(grep -v '^#' /usr/share/mino/flatpaks.txt)
    brew bundle --file /usr/share/mino/Brewfile
