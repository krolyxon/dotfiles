#!/bin/bash
mode=$(envycontrol -q | awk '{print $NF}')

case "$mode" in
    integrated)
        icon=""
        ;;
    hybrid)
        icon=""
        ;;
    nvidia)
        icon=""
        ;;
    *)
        icon=""
        ;;
esac

echo "$icon $mode"
