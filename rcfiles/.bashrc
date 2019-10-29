#
# ~/.bashrc
#

# If not running interactively, don't do anything
. ${HOME}/.profile
[[ $- != *i* ]] && return

. ~/.profile

declare -A uni
uni[check]='\u2713'
uni[ex]='\u2717'
PS1='`if [[ $? = 0 ]]; then echo -ne \[\033[32m\][${uni[check]}]; else echo -ne \[\033[31m\][${uni[ex]}]; fi`\[\e[0m\]\u@\h \W\$ '

alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias asdf='setxkbmap us -variant colemak'
alias rot13="tr '[A-Za-z]' '[N-ZA-Mn-za-m]'"

export LESS=-R LESS_TERMCAP_me=$(printf '\e[0m') LESS_TERMCAP_se=$(printf '\e[0m') LESS_TERMCAP_ue=$(printf '\e[0m') LESS_TERMCAP_mb=$(printf '\e[1;32m') LESS_TERMCAP_md=$(printf '\e[1;34m') LESS_TERMCAP_us=$(printf '\e[1;32m') LESS_TERMCAP_so=$(printf '\e[1;44;1m')
