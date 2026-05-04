# Arguments are:
# $1 - U|D|L|R
# $2 - Keys pressed (to forward on in the first case above) in tmux format
if [ $# -ne 2 ]; then echo Invalid args; exit 1; fi

# Check for WSL round-trip (WSL -> Windows git -> wsl.exe -> vim)
# tmux sees "init" as the pane command in this case
PANE_CMD="$(tmux display-message -p '#{pane_current_command}')"
if [ "$PANE_CMD" = "init" ]; then
	tmux send-keys $2
	exit 0
fi

TTY="$(tmux list-panes -F "#{pane_active} #{pane_tty}" | sed '/^1/!d;s/.*dev\///')"
if [ -z "$TTY" ]; then exit 1; fi
PROCS="$(ps -ao tty,comm | grep -E "^${TTY}\\s" | awk '{print $2}')"

if echo "$PROCS" | grep -E "ssh|tmux" >/dev/null 2>&1; then
	# pane running ssh or tmux
	tmux send-keys $2
elif echo "$PROCS" | grep -E "vim|nvim|vimdiff" >/dev/null 2>&1; then
	# pane running vim
	tmux send-keys $2
else
	# pane not running anything special
	tmux select-pane -$1
fi
