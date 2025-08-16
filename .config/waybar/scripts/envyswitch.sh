#!/bin/env bash

mode="$(printf "Integrated\nHybrid\nNvidia" | rofi -dmenu -case-smart -matching "fuzzy" -p "Select the graphics mode:")"

# Exit if no selection was made
[ -z "$mode" ] && exit 1

notify-send "Switching to $mode mode..."

# Map mode to envycontrol argument
arg=$(echo "$mode" | tr '[:upper:]' '[:lower:]')

if sudo -A envycontrol -s "$arg"; then
    notify-send "Graphics mode set to $mode"
else
    notify-send "Failed to set graphics mode to $mode"
fi
