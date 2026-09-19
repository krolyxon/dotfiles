#!/usr/bin/env bash

# Find the UPower device path for any connected headset/headphones
DEVICE_PATH=$(upower -e | grep -E 'headset|headphone' | head -n 1)

# If no headset device is found in UPower, exit silently so Waybar hides the module
if [ -z "$DEVICE_PATH" ]; then
    exit 0
fi

# Extract the percentage value (e.g., "90%")
PERCENTAGE=$(upower -i "$DEVICE_PATH" | awk '/percentage:/ {print $2}')

# Output JSON format for Waybar
if [ -n "$PERCENTAGE" ]; then
    printf '{"text": "%s", "tooltip": "Headset Battery: %s", "class": "connected"}\n' "$PERCENTAGE" "$PERCENTAGE"
fi
