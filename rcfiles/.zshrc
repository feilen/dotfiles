# TMUX
if which tmux >/dev/null 2>&1; then
    #if not inside a tmux session, and if no session is started, start a new session
    if [ ! -z $DISPLAY ] || [[ "$XDG_VTNR" != "1" ]]; then
        if [ -z "$TMUX" ]; then
            # If there's an unattached session, attach to it. Otherwise, create a new session
            UNATTACHED_SESSION="$(tmux list-sessions|grep -v attached|head -1|sed 's/:.*//g')"
            if [ ! -z "$UNATTACHED_SESSION" ]; then
                exec tmux -2 attach -t $UNATTACHED_SESSION
            else
                exec tmux -2 new-session
            fi
            exit $?
        fi
    fi
fi

if [[ "$PWD" == "/mnt/c/Windows/System32" ]]; then
    cd "$HOME"
fi

# Fuzzy ^R history search
export PATH="${HOME}/.local/dotfiles/zsh-plugins/fzf-zsh-plugin:${PATH}"
if which exa bat chafa exiftool >/dev/null; then
    export FZF_PREVIEW_ADVANCED=true FZF_PREVIEW_WINDOW="right:50%:nohidden"
else
    export FZF_PREVIEW_WINDOW="right:50%:nohidden"
fi
if which rg >/dev/null; then
    export RIPGREP_CONFIG_PATH="${HOME}/.ripgreprc"
    export FZF_DEFAULT_COMMAND='rg --files --no-ignore-vcs --hidden | rg -v "\.meta$"'
fi
if which nvim >/dev/null; then
    alias vim=nvim
    export EDITOR=nvim
fi
source "${HOME}/.local/dotfiles/zsh-plugins/fzf-zsh-plugin/fzf-zsh-plugin.plugin.zsh"
bindkey -M emacs '^F' fzf-file-widget
bindkey -M vicmd '^F' fzf-file-widget
bindkey -M viins '^F' fzf-file-widget

if which /usr/bin/keychain > /dev/null ; then
    /usr/bin/keychain -q --nogui $HOME/.ssh/dev
    source $HOME/.keychain/CJaggi-sh
fi

# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=10240
SAVEHIST=10240
bindkey -e
# End of lines configured by zsh-newuser-install
# The following lines were added by compinstall
zstyle :compinstall filename '/home/feilen/.zshrc'
# Automatically find new executables
zstyle ':completion:*' rehash true
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
unsetopt listambiguous
unsetopt LIST_BEEP
setopt NO_NOMATCH

autoload -Uz compinit
compinit
# End of lines added by compinstall

. ${HOME}/.profile
if [ -e ${HOME}/.profile_private ]; then
    . ${HOME}/.profile_private
fi

#------------------------------
# Prompt
#------------------------------

HOSTCOLOUR="$(cat ~/.local/hostcolour)"
#autoload -U promptinit
#promptinit
#prompt adam2 8bit 236 $HOSTCOLOUR $HOSTCOLOUR
eval `dircolors ~/.local/dotfiles/dircolors.ansi-dark`

function git_branch_name() {
    local branch_name
    git rev-parse --is-inside-work-tree > /dev/null 2>&1 || return
    branch_name=$(git describe --all --exact-match HEAD 2> /dev/null | sed 's/.*\///g')
    if [ "$(git log -1 --pretty=format:%ct $(git merge-base origin/master HEAD))" -lt "$(date -d '2 weeks ago' +%s)" ]; then
        echo -n "! "
    fi
    echo \> ${branch_name##refs/heads/}
}

function if_failed() {
    last_status=$?
    if [[ $last_status -ne 0 ]]; then
        echo "%F{red}return=${last_status}%f"
    fi
}

# Set up the prompt (with git branch name)
setopt PROMPT_SUBST
autoload -U colors && colors
PROMPT='┌(%F{${HOSTCOLOUR}}${PWD/#$HOME/~}%f) $(git_branch_name)
└> '
RPROMPT='$(if_failed)'


#------------------------------
# Window title
#------------------------------
case $TERM in
    termite|*xterm*|rxvt|rxvt-unicode|rxvt-256color|rxvt-unicode-256color|(dt|k|E)term|screen|screen-256color)
        precmd () {
            print -Pn "\e]0;%~\a"
        }
    preexec () {
        print -Pn "\e]0;$1\a"
    }
;;
screen|screen-256color)
    precmd () {
        print -Pn "\e]83;title \"$1\"\a"
        print -Pn "\e]0;$TERM - (%L) [%n@%M]%# [%~]\a"
    }
preexec () {
    print -Pn "\e]83;title \"$1\"\a"
    print -Pn "\e]0;$TERM - (%L) [%n@%M]%# [%~] ($1)\a"
}
;;
esac

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
source ${HOME}/.local/dotfiles/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# if we read .local/last_zsh_run and it's a new day, update last_zsh_run and fetch updates to .local/dotfiles
LAST_ZSH_RUN="$(cat ~/.local/last_zsh_run)"
if [[ "$LAST_ZSH_RUN" != "$(date '+%U')" ]]; then
    (
    cd ~/.local/dotfiles
    git fetch --all
    git submodule init
    if ! which gh > /dev/null ; then
        echo "gh not installed, won't be able to show github issues"
    fi
    date '+%U' > ~/.local/last_zsh_run

    GIT_CHERRY="$(git cherry HEAD origin/master)"
    GIT_MODIFIED="$(git status -s | grep '^ [MD]')"
    if [[ ! -z "$GIT_CHERRY" ]]; then
        echo "The following changes need to be pulled in:"
        echo "$GIT_CHERRY"
    fi
    if [[ ! -z "$GIT_MODIFIED" ]]; then
        echo "The following have been changed and need to be merged:"
        echo "$GIT_MODIFIED"
    fi
    ) &
fi

alias chels-issues="gh api -X GET issues -F per_page='100'| jq 'map(select(any(.labels[].name; test(\"fixed in dev branch|future release|support pending\"))| not) ) | group_by(.repository.name)[] | {(.[0].repository.name): [.[] | .title  | .[0:75]]}'"
LAST_MOTD="$(cat ~/.local/last_motd)"
if [[ "$LAST_MOTD" != "$(date '+%j')" ]]; then
#    if which gh > /dev/null ; then
#        ISSUES_LIST="$(chels-issues)"
#        if [[ ! -z "$ISSUES_LIST" ]]; then
#            echo "Assigned github issues:"
#            PAGER= chels-issues
#        fi
#    fi
#    (
#        if [[ -e "/home/feilen/.ssh/motd-credentials" ]]; then
#            localmotd
#        fi
#
#        if [[ -e "/etc/motd" ]]; then
#            cat /etc/motd
#        fi
#    )
    # Ensure default git-template exists
    if [ -z "$(git config --path --get init.templatedir)" ]; then
        git config --global init.templatedir '~/.local/dotfiles/git-template'
    fi
    (
    # Sanity/Setup checks
    if ! which exa batcat chafa flake8 cppcheck nvim xclip ctags shellcheck rg > /dev/null ; then
        if ! which rg > /dev/null ; then
            echo "ripgrep does not appear to be installed. vim will use gitgrep"
        fi
        if ! which shellcheck > /dev/null ; then
            echo "shellcheck does not appear to be installed"
        fi
        if ! which ctags > /dev/null ; then
            echo "ctags does not appear to be installed. Source indexing won't work."
        fi
        if ! which xclip clip.exe > /dev/null ; then
            if [ -z "$SSH_CONNECTION" ]; then
                echo "xclip does not appear to be installed. Copy will not work"
            fi
        fi
        if ! which nvim > /dev/null ; then
            echo "nvim does not appear to be installed. Copy will not work"
        fi
        if ! which cppcheck > /dev/null; then
            echo "cppcheck does not appear to be installed"
        fi
        if ! which batcat > /dev/null; then
            echo "bat does not appear to be installed"
        fi
        if [[ "$(lsb_release -rs|sed 's/[^0-9]//g')" -gt "2004" ]]; then
            if ! which exa > /dev/null; then
                echo "exa does not appear to be installed"
            fi
        fi
        if ! which chafa > /dev/null; then
            echo "chafa does not appear to be installed"
        fi
        if ! which flake8 > /dev/null; then
            echo "flake8 does not appear to be installed"
        fi
    fi

    if which python3 > /dev/null ; then
        if ! echo "import pylint" | python3 2>/dev/null > /dev/null ; then
            echo "Pylint not installed for python3"
        fi
        if ! echo "import pyflakes" | python3 2>/dev/null > /dev/null ; then
            echo "Pyflakes not installed for python3"
        fi
    fi
    ) &

    date '+%j' > ~/.local/last_motd
fi


# Aliases
alias ls='ls --color=auto -tr1'
alias grep='grep --color=auto'
alias asdf='setxkbmap us -variant colemak'
alias CSMTFIX='wine reg add "HKCU\\Software\\Wine\\Direct3D\\" /v CSMT /t REG_SZ /d "enabled" /f; wine reg add "HKCU\\Software\\Wine\\Direct3D\\" /v StrictDrawOrdering /t REG_SZ /d "disabled" /f'
alias DWRITEFIX='wine reg add "HKCU\\Software\\Valve\\Steam" /v DWriteEnable /t REG_DWORD /d 00000000'
alias D3DADFIX='wine reg.exe ADD "HKCU\\Software\\Wine\\Direct3D" /v UseNative /t REG_DWORD /d 1'

alias chels-show-package-files='dpkg -L'
alias chels-bell="/bin/sh -c \"echo -ne '\x07' && sleep 0.15 && echo -ne '\x07' && sleep 1 && echo -ne '\x07' && sleep 1 && echo -ne '\x07' && sleep 0.15 && echo -ne '\x07'\" &"
if grep -qi Microsoft /proc/version ; then
    alias chels-copy='clip.exe'
else
    alias chels-copy='xclip -selection clipboard -i'
fi
if which gh > /dev/null; then
    alias chels-motd="chels-issues; localmotd; [[ -e /etc/motd ]] && cat /etc/motd"
fi

wait
[[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && exec startx > .Xsession-log
