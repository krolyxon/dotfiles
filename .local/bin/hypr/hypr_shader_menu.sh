#!/usr/bin/env bash
set -euo pipefail

# Check deps
command -v aurora-run >/dev/null || { echo "aurora-run not found"; exit 1; }
command -v hyprshade >/dev/null || { echo "hyprshade not found"; exit 1; }

# Get shader list
mapfile -t SHADERS < <(hyprshade ls)

# Add "off" at top
SHADERS=("off" "${SHADERS[@]}")

# Show in aurora's runner (|| true: cancelling must not trip set -e)
CHOICE=$(printf "%s\n" "${SHADERS[@]}" \
    | { aurora-run --dmenu --prompt "Hyprshade > " || true; } \
    | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

# User cancelled
[[ -z "$CHOICE" ]] && exit 0

# Apply
if [[ "$CHOICE" == "off" ]]; then
    hyprshade off
else
    hyprshade on "$CHOICE"
fi

# Optional notification
command -v notify-send >/dev/null && notify-send "Hyprshade" "Applied: $CHOICE"

