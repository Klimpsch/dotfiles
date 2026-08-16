# .bashrc
export PATH="$HOME/bin:$PATH"
# Source global definitions
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# User specific environment
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]; then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH
export EDITOR='vim'
export VISUAL='vim'


# User specific aliases and functions
if [ -d ~/.bashrc.d ]; then
    for rc in ~/.bashrc.d/*; do
        if [ -f "$rc" ]; then
            . "$rc"
        fi
    done
fi
unset rc


# Inhibit sleep for 5 hours on SSH login
if [ -n "$SSH_CONNECTION" ] && [ -z "$SLEEP_INHIBITED" ]; then
    export SLEEP_INHIBITED=1
    systemd-inhibit --what=idle:sleep --why="SSH session" --mode=block sleep 18000 &
    disown
fi


gitpullall() {
    for dir in ~/git/*/; do
        if [ -d "$dir/.git" ]; then
            echo -e "\033[36m==> $(basename "$dir")\033[0m"
            git -C "$dir" pull
        fi
    done
}

gitpushall() {
    for dir in ~/git/*/; do
        if [ -d "$dir/.git" ]; then
            echo -e "\033[36m==> $(basename "$dir")\033[0m"
            if [ -n "$(git -C "$dir" status --porcelain)" ]; then
                git -C "$dir" add -A
                git -C "$dir" commit -m "sync $(date +%Y-%m-%d)"
                git -C "$dir" push || echo -e "\033[31m   push failed\033[0m"
            else
                echo -e "\033[90m   clean — nothing to commit\033[0m"
            fi
        fi
    done
}


# One-line status for every repo under ~/git
gitstatall() {
    for dir in ~/git/*/; do
        if [ -d "$dir/.git" ]; then
            branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)
            if [ -n "$(git -C "$dir" status --porcelain 2>/dev/null)" ]; then
                state="dirty"; color="\033[33m"
            else
                state="clean"; color="\033[32m"
            fi
            printf "${color}%-25s %-15s %s\033[0m\n" "$(basename "$dir")" "$branch" "$state"
        fi
    done
}

open() { xdg-open "${1:-.}" >/dev/null 2>&1; }   # macOS: replace xdg-open with open
repos() { cd ~/git; }
reload() { source ~/.bashrc && echo -e "\033[32mbashrc reloaded.\033[0m"; }

alias vim='nvim'
alias gpull='gitpullall'
alias gpush='gitpushall'
alias gstat='gitstatall'
alias ls='ls --color=auto --group-directories-first -h -F -l'
alias dps='docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.Image}}"'


HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth          # ignore dupes and lines starting with a space
shopt -s histappend             # append instead of overwriting
PROMPT_COMMAND="history -a; ${PROMPT_COMMAND:-}"   # write history after each command

