#!/usr/bin/env bash
if [ ! -e ~/.local/tmux_hostcolour.conf ]; then
	HASH_FROM_HOST=$(echo "$HOST" | md5sum | awk '{print $1}' | cut -c 1-4 | cat <(echo -n 0x) -)
	COLOURCODE=$(echo "print(int(${HASH_FROM_HOST} / 312.07 + 20.0))" | python3)
	echo "Calculated color for host:" $COLOURCODE
	echo -n "set-option -g status-fg colour" > ~/.local/tmux_hostcolour.conf
	echo "$COLOURCODE" >> ~/.local/tmux_hostcolour.conf
	echo -n "set-option -g window-status-current-style fg=colour" >> ~/.local/tmux_hostcolour.conf
	echo "$COLOURCODE" >> ~/.local/tmux_hostcolour.conf
	echo -n "set -g pane-active-border-style fg=colour" >> ~/.local/tmux_hostcolour.conf
	echo "$COLOURCODE" >> ~/.local/tmux_hostcolour.conf
	cat ~/.local/tmux_hostcolour.conf
	echo -n "$COLOURCODE" > ~/.local/hostcolour
fi
