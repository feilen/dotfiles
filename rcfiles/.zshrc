# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=1024
SAVEHIST=1024
bindkey -e
# End of lines configured by zsh-newuser-install
# The following lines were added by compinstall
zstyle :compinstall filename '/home/feilen/.zshrc'

autoload -Uz compinit
compinit
# End of lines added by compinstall

. ${HOME}/.profile

#------------------------------
# Prompt
#------------------------------

autoload -U promptinit
promptinit
prompt adam2

#------------------------------
# Window title
#------------------------------
case $TERM in
  termite|*xterm*|rxvt|rxvt-unicode|rxvt-256color|rxvt-unicode-256color|(dt|k|E)term)
    precmd () {
      #vcs_info
      print -Pn "\e]0;[%n@%M][%~]%#\a"
    } 
    preexec () { print -Pn "\e]0;[%n@%M][%~]%# ($1)\a" }
    ;;
  screen|screen-256color)
    precmd () { 
      #vcs_info
      print -Pn "\e]83;title \"$1\"\a" 
      print -Pn "\e]0;$TERM - (%L) [%n@%M]%# [%~]\a" 
    }
    preexec () { 
      print -Pn "\e]83;title \"$1\"\a" 
      print -Pn "\e]0;$TERM - (%L) [%n@%M]%# [%~] ($1)\a" 
    }
    ;; 
esac


alias ls='ls --color=auto -tr'
alias ghc='ghc -O1'
alias grep='grep --color=auto'
alias asdf='setxkbmap us -variant colemak'
alias postinstall='sudo bleachbit -c --preset;sudo prelink -amR -C /var/cache/prelink.cache'
alias CSMTFIX='wine reg add "HKCU\\Software\\Wine\\Direct3D\\" /v CSMT /t REG_SZ /d "enabled" /f; wine reg add "HKCU\\Software\\Wine\\Direct3D\\" /v StrictDrawOrdering /t REG_SZ /d "disabled" /f'
alias DWRITEFIX='wine reg add "HKCU\\Software\\Valve\\Steam" /v DWriteEnable /t REG_DWORD /d 00000000'
alias D3DADFIX='wine reg.exe ADD "HKCU\\Software\\Wine\\Direct3D" /v UseNative /t REG_DWORD /d 1'
alias nicewine='schedtool -n 1 $(allthreads "C:/Program Files/Steam/Steam.exe")'
alias wololo='ssh media@htpc wol d0:50:99:37:f3:1d'

# create a zkbd compatible hash;
# to add other keys to this hash, see: man 5 terminfo
typeset -A key

key[Home]=${terminfo[khome]}
key[End]=${terminfo[kend]}
key[Insert]=${terminfo[kich1]}
key[Delete]=${terminfo[kdch1]}
key[Up]=${terminfo[kcuu1]}
key[Down]=${terminfo[kcud1]}
key[Left]=${terminfo[kcub1]}
key[Right]=${terminfo[kcuf1]}
key[PageUp]=${terminfo[kpp]}
key[PageDown]=${terminfo[knp]}

# setup key accordingly
[[ -n "${key[Home]}"    ]]  && bindkey  "${key[Home]}"    beginning-of-line
[[ -n "${key[End]}"     ]]  && bindkey  "${key[End]}"     end-of-line
[[ -n "${key[Insert]}"  ]]  && bindkey  "${key[Insert]}"  overwrite-mode
[[ -n "${key[Delete]}"  ]]  && bindkey  "${key[Delete]}"  delete-char
[[ -n "${key[Up]}"      ]]  && bindkey  "${key[Up]}"      up-line-or-history
[[ -n "${key[Down]}"    ]]  && bindkey  "${key[Down]}"    down-line-or-history
[[ -n "${key[Left]}"    ]]  && bindkey  "${key[Left]}"    backward-char
[[ -n "${key[Right]}"   ]]  && bindkey  "${key[Right]}"   forward-char
bindkey  "^[[1;5D"   backward-word
bindkey  "^[[1;5C"   forward-word

# Finally, make sure the terminal is in application mode, when zle is
# active. Only then are the values from $terminfo valid.
function zle-line-init () {
    echoti smkx
}
function zle-line-finish () {
    echoti rmkx
}
#zle -N zle-line-init
#zle -N zle-line-finish  
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

[[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && exec startx > .Xsession-log
