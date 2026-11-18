#!/usr/bin/env bash
# Install a USGC theme for Kate: editor colours, window colours, terminal panel,
# and (optionally) bigger menu/UI fonts. Changes apply to Kate only.
#
#   ./install-usgc-kate.sh light                 # light theme, UI font 12pt
#   ./install-usgc-kate.sh dark --font-size 13   # dark theme, UI font 13pt
#   ./install-usgc-kate.sh light --font-size 0   # theme only, leave fonts alone
#   ./install-usgc-kate.sh --reset-fonts         # undo the font change
#
# Close Kate before running; it rewrites katerc when it exits.
set -euo pipefail
cd "$(dirname "$0")"

usage() { sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

THEME="" FONT_SIZE=12 RESET_FONTS=0
while [ $# -gt 0 ]; do
  case "$1" in
    light|dark) THEME=$1 ;;
    --font-size) FONT_SIZE=${2:?--font-size needs a number}; shift ;;
    --reset-fonts) RESET_FONTS=1 ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
  shift
done
[ -n "$THEME" ] || [ "$RESET_FONTS" = 1 ] || usage
[[ "$FONT_SIZE" =~ ^[0-9]+$ ]] || { echo "--font-size must be a whole number" >&2; exit 1; }

if pgrep -x kate >/dev/null; then
  echo "Kate is running. Close it first, then re-run this script." >&2
  exit 1
fi

if command -v kwriteconfig6 >/dev/null; then KW=kwriteconfig6 KR=kreadconfig6
elif command -v kwriteconfig5 >/dev/null; then KW=kwriteconfig5 KR=kreadconfig5
else echo "kwriteconfig6/5 not found (install kf6-kconfig)." >&2; exit 1
fi

FONT_KEYS=(font menuFont toolBarFont smallestReadableFont)

if [ "$RESET_FONTS" = 1 ]; then
  for k in "${FONT_KEYS[@]}"; do $KW --file katerc --group General --key "$k" --delete; done
  echo "Kate's UI fonts reset to the system defaults."
  [ -z "$THEME" ] && exit 0
fi

DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
if [ "$THEME" = light ]; then NAME="USGC Light" ID=USGCLight SLUG=usgc-light
else                          NAME="USGC Dark"  ID=USGCDark  SLUG=usgc-dark
fi

install -Dm644 "$SLUG.theme"        "$DATA/org.kde.syntax-highlighting/themes/$SLUG.theme"
install -Dm644 "$ID.colors"         "$DATA/color-schemes/$ID.colors"
install -Dm644 "$ID.colorscheme"    "$DATA/konsole/$ID.colorscheme"
install -Dm644 "$NAME.profile"      "$DATA/konsole/$NAME.profile"

# editor colours (and stop Kate auto-switching with the system light/dark setting)
$KW --file katerc --group "KTextEditor Renderer" --key "Color Theme" "$NAME"
$KW --file katerc --group "KTextEditor Renderer" --key "Auto Color Theme Selection" false
# window colours: menus, sidebars, tabs, status bar
$KW --file katerc --group UiSettings --key ColorScheme "$NAME"
# terminal panel (standalone Konsole keeps its own default profile)
$KW --file katerc --group "Desktop Entry" --key DefaultProfile "$NAME.profile"

# UI fonts: start from your system fonts and change only the size, Kate only
if [ "$RESET_FONTS" = 0 ] && [ "$FONT_SIZE" -gt 0 ]; then
  for k in "${FONT_KEYS[@]}"; do
    cur=$($KR --file kdeglobals --group General --key "$k" || true)
    [ -n "$cur" ] || cur="Noto Sans,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
    size=$FONT_SIZE
    [ "$k" = smallestReadableFont ] && size=$((FONT_SIZE > 9 ? FONT_SIZE - 2 : FONT_SIZE))
    IFS=',' read -ra p <<< "$cur"
    p[1]=$size; p[2]=-1          # point size; clear any pixel size
    new=$(IFS=,; echo "${p[*]}")
    $KW --file katerc --group General --key "$k" "$new"
  done
  echo "Kate's menu/UI font size set to ${FONT_SIZE}pt."
fi

echo "Installed $NAME. Start Kate to see it."
