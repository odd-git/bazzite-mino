# Restore user-level apps on a fresh install: Flatpaks and Homebrew.
# One failing app (e.g. a Flathub extra-data mismatch) must not stop the rest.
mino-restore:
    #!/usr/bin/bash
    set -uo pipefail
    failed=()
    while read -r app; do
        flatpak install -y --noninteractive flathub "$app" </dev/null || failed+=("$app")
    done < <(grep -v '^#' /usr/share/mino/flatpaks.txt)
    brew bundle --file /usr/share/mino/Brewfile || failed+=("brew-bundle")
    if [ ${#failed[@]} -gt 0 ]; then
        echo "FAILED: ${failed[*]}" >&2
        exit 1
    fi
