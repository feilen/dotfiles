#!/bin/bash
#
# ~/.xinitrc
#
# Executed by startx (run your window manager from here)

# Source in the profile script
. /home/feilen/.profile

if [ -d /etc/X11/xinit/xinitrc.d ]; then
  for f in /etc/X11/xinit/xinitrc.d/*; do
    [ -x "$f" ] && . "$f"
  done
  unset f
fi

#Keyboard
setxkbmap us -variant colemak

#Audio
pulseaudio --start

#Screen
xrandunrift
nvidia-settings -l
synckeeper &

#Begin

#exec wmfs
exec startxfce4
