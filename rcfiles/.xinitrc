#!/bin/sh
#
# ~/.xinitrc
#
# Executed by startx (run your window manager from here)

# Source in the profile script
. ${HOME}/.profile

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

#Keyring
eval $(/usr/bin/gnome-keyring-daemon --start --components=pkcs11,secrets,ssh)
export SSH_AUTH_SOCK

#Begin
#compton -cCzG -t-3 -l-5 -r4 \
#     --config /dev/null --backend xrender \
#      --unredir-if-possible &
exec startxfce4
