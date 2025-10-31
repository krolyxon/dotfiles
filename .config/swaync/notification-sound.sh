#!/bin/bash

if [ $(swaync-client -D) = "false" ]; then
	paplay ~/.config/swaync/i-am-loving-it.mp3
fi
