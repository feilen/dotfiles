#!/bin/sh
if [ ! -e ~/.local/tmux_hostcolour.conf ]; then
	HASH_FROM_HOST=$(hostname | md5sum | awk '{print $1}' | cut -c 1-4)
	HASH_FROM_HOST="0x${HASH_FROM_HOST}"
	COLOURCODE=$(printf "print(int(%s / 312.07 + 20.0))" "$HASH_FROM_HOST" | python3)
	echo "Calculated color for host:" "$COLOURCODE"
	printf "set-option -g status-fg colour" > ~/.local/tmux_hostcolour.conf
	echo "$COLOURCODE" >> ~/.local/tmux_hostcolour.conf
	printf "set-option -g window-status-current-style fg=colour" >> ~/.local/tmux_hostcolour.conf
	echo "$COLOURCODE" >> ~/.local/tmux_hostcolour.conf
	printf "set -g pane-active-border-style fg=colour" >> ~/.local/tmux_hostcolour.conf
	echo "$COLOURCODE" >> ~/.local/tmux_hostcolour.conf
	cat ~/.local/tmux_hostcolour.conf
	printf "%s" "$COLOURCODE" > ~/.local/hostcolour
fi
