#!/usr/bin/sh
[[ -z "${DOTPROFILE}" ]] || return
DOTPROFILE=1 #We've loaded this script

export WINEDEBUG=-all \
STEAM_FRAME_FORCE_CLOSE=1 \
SDL_AUDIO=pulse \
SDL_AUDIODRIVER=pulse \
#PATH=${HOME}/.local/bin:${HOME}/.local/dotfiles/riftutilities:/usr/lib/ccache/bin/:${PATH} \
WINEPREFIX=${HOME}/.wine/default \
EDITOR=vim \
VISUAL=vim \
PAGER="/bin/sh -c \"unset PAGER;col -x -b | \
    vim -R -c 'set ft=man nomod nolist' -c 'map q :q<CR>' \
    -c 'map <SPACE> <C-D>' -c 'map b <C-U>' \
    -c 'setfiletype diff' \
    -c 'nmap K :Man <C-R>=expand(\\\"<cword>\\\")<CR><CR>' -\"" \
BROWSER=firefox 
#GTK2_RC_FILES="/usr/share/themes/Arch/gtk-2.0/gtkrc"
