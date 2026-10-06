#!/usr/bin/env bash
# Pin AMD GPU clocks high while an external display is connected, to stop
# HDMI-audio stutter on jitter-sensitive sinks (e.g. XGIMI). Reverts on unplug.
GPU=/sys/class/drm/card1/device
LEVEL="$GPU/power_dpm_force_performance_level"
[ -e "$LEVEL" ] || exit 0
ext=0
for s in /sys/class/drm/card1/card1-DP-*/status /sys/class/drm/card1/card1-HDMI-*/status; do
    [ -e "$s" ] || continue
    [ "$(cat "$s")" = connected ] && ext=1
done
if [ "$ext" = 1 ]; then
    echo high > "$LEVEL"   # pins clocks -> no glitchy memory-clock switching
else
    echo auto > "$LEVEL"   # full power saving when projector unplugged
fi
