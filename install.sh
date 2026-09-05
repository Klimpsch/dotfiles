#!/usr/bin/env bash
set -euo pipefail

# Directory this script lives in = the repo root
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# map: repo filename (WITH dot) -> target path in $HOME
declare -A LINKS=(
  [.bashrc]="$HOME/.bashrc"
  [.vimrc]="$HOME/.vimrc"
)

for src in "${!LINKS[@]}"; do
  target="${LINKS[$src]}"

  # safety: make sure the source file actually exists before linking,
  # otherwise ln would create a broken symlink pointing at nothing
  if [ ! -e "$DOTFILES/$src" ]; then
    echo "WARNING: $DOTFILES/$src not found — skipping"
    continue
  fi

  # back up an existing real file (not a symlink) before replacing
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    echo "Backing up existing $target -> $target.bak"
    mv "$target" "$target.bak"
  fi

  ln -sfn "$DOTFILES/$src" "$target"
  echo "Linked $target -> $DOTFILES/$src"
done

echo "Run: source ~/.bashrc"
