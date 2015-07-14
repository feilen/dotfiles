#!/bin/sh
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

#Screen
if [ "$(cat /etc/hostname)" == "MAWnster" ]; then
	xrandunrift
	nvidia-settings -l
	#synckeeper &
else
	syndaemon -i .5 -K -t -R -d
fi

#Begin
#exec startxfce4
#exec xterm

exec startlxde
