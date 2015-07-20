#!/usr/bin/sh
[[ -z "${DOTPROFILE}" ]] || return
DOTPROFILE=1 #We've loaded this script

export WINEDEBUG=-all \
STEAM_FRAME_FORCE_CLOSE=1 \
STEAM_RUNTIME=0 \
SDL_AUDIO=pulse \
SDL_AUDIODRIVER=pulse \
PATH=${HOME}/.local/bin:${HOME}/.local/dotfiles/riftutilities:${PATH} \
WINEPREFIX=${HOME}/.wine/default \
EDITOR=vim \
PAGER=less \
VISUAL=gvim \
BROWSER=firefox 
#GTK2_RC_FILES="/usr/share/themes/Arch/gtk-2.0/gtkrc"

alias firefox='env GTK2_RC_FILES="/usr/share/themes/Equinox Evolution Dawn/gtk-2.0/gtkrc" /usr/lib/firefox/firefox'
