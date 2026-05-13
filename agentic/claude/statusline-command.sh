#!/bin/bash

# Read JSON input
input=$(cat)

# Extract data from JSON
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
model=$(echo "$input" | jq -r '.model.display_name')
session_name=$(echo "$input" | jq -r '.session_name // empty')

# Get git branch name first (with skip optional locks for performance)
get_git_branch() {
    local branch_name
    local inside_tree
    inside_tree=$(cd "$cwd" 2>/dev/null && git --no-optional-locks rev-parse --is-inside-work-tree 2>&1)
    if [ $? -ne 0 ]; then
        return 1
    fi
    if [[ "$inside_tree" == "false" ]]; then
        return 1
    fi
    branch_name=$(cd "$cwd" 2>/dev/null && git --no-optional-locks describe --all --exact-match HEAD 2> /dev/null | sed 's/.*\///g')
    if [ -n "$branch_name" ]; then
        echo "${branch_name##refs/heads/}"
        return 0
    fi
    return 1
}

# Get branch and calculate hostcolour from branch name hash
branch=$(get_git_branch)
if [ -n "$branch" ]; then
    # Hash the branch name and take last 3 bits (0-7 range), then map to color range
    # We'll use modulo 232 to get a color in the 256-color palette range
    hash_val=$(echo -n "$branch" | md5sum | cut -c1-8)
    HOSTCOLOUR=$((0x${hash_val} % 232 + 16))  # 16-247 are the 232 safe colors
else
    # Default color when not in git repo
    HOSTCOLOUR=111
fi

# Function to format path like zsh prompt_path()
format_path() {
    local p="${cwd/#$HOME/~}"
    if [[ "$p" == "/" || "$p" == "~" ]]; then
        printf "\033[38;5;${HOSTCOLOUR}m${p}\033[0m"
    else
        local dir=$(dirname "$p")
        local base=$(basename "$p")
        printf "\033[38;5;4m${dir}/\033[0m\033[38;5;${HOSTCOLOUR}m${base}\033[0m"
    fi
}

# Format git branch for display
git_branch_name() {
    if [ -n "$branch" ]; then
        echo -n " > ${branch}"
    fi
}

# Build the status line
output="$(format_path) $(git_branch_name)"

# Add session name if present
if [ -n "$session_name" ]; then
    output="$output \033[2m[$session_name]\033[0m"
fi

# Add context usage percentage if available (right-adjusted)
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
if [ -n "$used_pct" ]; then
    # Divide by 0.438690185546875 to get effective percentage
    adjusted_pct=$(echo "$used_pct / 0.438690185546875" | bc -l)
    context_str="[Context: $(printf '%.0f' "$adjusted_pct")%]"

    # Get terminal width and calculate padding
    term_width=$(tput cols 2>/dev/null || echo 80)
    # Strip ANSI codes to get visible length of output
    visible_output=$(echo -e "$output" | sed 's/\x1b\[[0-9;]*m//g')
    visible_len=${#visible_output}
    context_len=${#context_str}
    padding=$((term_width - visible_len - context_len - 1))

    if [ $padding -gt 0 ]; then
        output="$output$(printf '%*s' $padding '')\033[2m$context_str\033[0m"
    else
        output="$output \033[2m$context_str\033[0m"
    fi
fi

echo -e "$output"
