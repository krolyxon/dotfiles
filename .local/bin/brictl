#!/usr/bin/env sh
# Source: https://github.com/albertnis/hypr-brightness
#  Install ddcutil, and then enable access to i2c for your user

# sudo gpasswd -a $USER i2c
# sudo modprobe i2c-dev
# echo i2c-dev | sudo tee /etc/modules-load.d/i2c-dev.conf

set +e

usage="Usage: $0 [+] or [-]"

if [ "$#" -ne 1 ]; then
    echo "No direction parameter provided"
    echo "$usage"
    exit 1
fi

arg="$1"

if [ "$arg" == "help" ] || [ "$arg" == "--help" ] || [ "$arg" == "-h" ]; then
    echo "$usage"
    exit 0
fi

if [ "$arg" != "+" ] && [ "$arg" != "-" ]; then
    echo "Direction parameter must be '+' or '-'"
    echo $usage
    exit 1
fi

direction=$arg

monitor_data=$(hyprctl monitors -j)
focused_name=$(echo $monitor_data | jq -r '.[] | select(.focused == true) | .name')

if [ "$focused_name" == "eDP-1" ]; then
    if [ "$direction" == "-" ]; then
        brightnessctl -e4 -n2 set 5%-
    else
        brightnessctl -e4 -n2 set 5%+
    fi
else
    focused_id=$(echo $monitor_data | jq -r '.[] | select(.focused == true) | .id')
    ddcutil  --enable-dynamic-sleep --display=$focused_id setvcp 10 $direction 15
fi
