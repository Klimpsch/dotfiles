#!/usr/bin/env bash
set -euo pipefail

# Directory this script lives in = the repo root
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# map: repo filename -> target path in $HOME
declare -A LINKS=(
  [bashrc]="$HOME/.bashrc"
  [vimrc]="$HOME/.vimrc"
)

for src in "${!LINKS[@]}"; do
  target="${LINKS[$src]}"
  # back up an existing real file (not a symlink) before replacing
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    echo "Backing up existing $target -> $target.bak"
    mv "$target" "$target.bak"
  fi
  ln -sfn "$DOTFILES/$src" "$target"
  echo "Linked $target -> $DOTFILES/$src"
done

echo "Run: source ~/.bashrc"
