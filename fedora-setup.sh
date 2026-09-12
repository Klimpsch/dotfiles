#!/usr/bin/env bash
#
# fedora-setup.sh — post-install setup for a fresh Fedora Workstation
#
#   - Tunes dnf (parallel downloads, fastest mirror, default yes)
#   - Enables RPM Fusion (free + nonfree)
#   - Installs development tools & build essentials
#   - Installs and lightly configures Neovim (+ classic Vim)
#   - Installs the KVM/QEMU/libvirt virtualization stack + Cockpit
#   - Installs Podman, gnome-tweaks, developer fonts, snapper
#   - Installs NVIDIA drivers (with Secure Boot / MOK handling)
#   - Applies firmware updates
#   - Clones your git repos into ~/repos/
#
# USAGE:
#   1. Edit the REPOS array below to list YOUR repositories.
#   2. Review the package lists and remove anything you don't want.
#   3. chmod +x fedora-setup.sh && ./fedora-setup.sh
#
#   Flags:
#     --dry-run    Print every command that would run, without executing it.
#     -h, --help   Show this help and exit.
#
# Run as your normal user (NOT as root). It will call sudo where needed.
# ---------------------------------------------------------------------------

set -euo pipefail

# --- argument parsing ------------------------------------------------------
DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -h|--help)
      # Print the leading comment block (lines starting with #), stopping at
      # the first non-comment line, with the leading '# ' stripped.
      awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$0"
      exit 0
      ;;
    *)
      printf 'Unknown option: %s (try --help)\n' "$arg" >&2
      exit 2
      ;;
  esac
done

# ====== EDIT THIS: your git repositories ===================================
# Add each repo's clone URL. SSH form (git@github.com:user/repo.git) requires
# your SSH key to be set up first; HTTPS form works immediately.
REPOS=(
  # "git@github.com:yourname/repo-one.git"
  # "git@github.com:yourname/repo-two.git"
  # "https://github.com/yourname/repo-three.git"
)

# Directory to clone all repos into
REPO_DIR="$HOME/repos"
# ===========================================================================


# --- pretty output helpers -------------------------------------------------
info()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
err()   { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; }

# Ask a yes/no question. Returns 0 for yes, 1 for no. Defaults to no on
# non-interactive shells (so unattended runs don't hang).
ask() {
  local prompt="$1" reply
  if [[ ! -t 0 ]]; then
    warn "Non-interactive shell — assuming 'no' for: $prompt"
    return 1
  fi
  read -rp "$(printf '\033[1;36m[?]\033[0m %s [y/N] ' "$prompt")" reply
  [[ "$reply" =~ ^[Yy]$ ]]
}

# Current login name — derived from id(1) so it's always set even when the
# USER environment variable isn't exported (safe under 'set -u').
USERNAME="$(id -un)"

# True if a dnf package is already installed.
pkg_installed() { rpm -q "$1" &>/dev/null; }

# Execute a command, or just print it under --dry-run. Use this for any
# command that changes system state (installs, systemctl, writes, gsettings).
# Read-only probes (rpm -q, lspci, grep, command -v) are NOT wrapped.
run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    printf '\033[1;35m[dry-run]\033[0m %s\n' "$*"
  else
    "$@"
  fi
}

# Register a GNOME custom media-keys keybinding, idempotently.
#   $1 = slot id (unique, no spaces)   e.g. open-terminal
#   $2 = human name                    e.g. "Open Terminal"
#   $3 = command to run                e.g. ptyxis
#   $4 = key binding                   e.g. "<Control>t"
# Appends the slot to the custom-keybindings list only if absent, then sets
# its name/command/binding. Safe to re-run. Handles multiple registrations in
# one run (including under --dry-run) by remembering slots we've added.
_KB_ADDED=""
register_custom_keybinding() {
  local slot="$1" kbname="$2" kbcmd="$3" kbbind="$4"
  local base="org.gnome.settings-daemon.plugins.media-keys"
  local kbpath="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/${slot}/"

  local current
  current="$(gsettings get "$base" custom-keybindings 2>/dev/null || echo '@as []')"
  # In dry-run the earlier 'set' didn't take, so fold in slots we've queued.
  if [[ $DRY_RUN -eq 1 && -n "$_KB_ADDED" ]]; then
    if [[ "$current" == "@as []" || "$current" == "[]" ]]; then
      current="[${_KB_ADDED%, }]"
    else
      current="${current%]}, ${_KB_ADDED%, }]"
    fi
  fi

  if printf '%s' "$current" | grep -q "$kbpath"; then
    info "Keybinding '$kbname' already registered."
  else
    local newlist
    if [[ "$current" == "@as []" || "$current" == "[]" ]]; then
      newlist="['$kbpath']"
    else
      newlist="${current%]}, '$kbpath']"
    fi
    run gsettings set "$base" custom-keybindings "$newlist"
    _KB_ADDED+="'$kbpath', "
  fi

  local ckb="${base}.custom-keybinding:${kbpath}"
  run gsettings set "$ckb" name "$kbname"
  run gsettings set "$ckb" command "$kbcmd"
  run gsettings set "$ckb" binding "$kbbind"
  info "$kbname → '$kbcmd' on $kbbind"
}

if [[ $EUID -eq 0 ]]; then
  err "Do not run this script as root. Run as your normal user; it uses sudo when needed."
  exit 1
fi

if [[ $DRY_RUN -eq 1 ]]; then
  warn "DRY RUN: no changes will be made. Commands that would run are printed with [dry-run]."
fi

# Keep sudo alive for the whole run (skipped in dry-run — we run nothing).
if [[ $DRY_RUN -eq 0 ]]; then
  info "Requesting sudo (you'll be prompted once)…"
  sudo -v
  # refresh sudo timestamp in the background until the script ends
  ( while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) &
fi

# --- 0. dnf speedups -------------------------------------------------------
# Set max_parallel_downloads, fastestmirror and defaultyes in dnf.conf.
# Each key is added only if absent, or updated in place if already present,
# so the file stays clean across re-runs.
info "Tuning dnf configuration…"
DNF_CONF="/etc/dnf/dnf.conf"
declare -A DNF_SETTINGS=(
  [max_parallel_downloads]=10
  [fastestmirror]=True
  [defaultyes]=True
)
for key in "${!DNF_SETTINGS[@]}"; do
  val="${DNF_SETTINGS[$key]}"
  if sudo grep -Eq "^${key}=" "$DNF_CONF" 2>/dev/null; then
    current="$(sudo grep -E "^${key}=" "$DNF_CONF" | head -1 | cut -d= -f2)"
    if [[ "$current" == "$val" ]]; then
      info "  dnf: $key already = $val"
    else
      info "  dnf: updating $key = $val (was $current)"
      run sudo sed -i -E "s|^${key}=.*|${key}=${val}|" "$DNF_CONF"
    fi
  else
    info "  dnf: adding $key = $val"
    if [[ $DRY_RUN -eq 1 ]]; then
      printf '\033[1;35m[dry-run]\033[0m append %s=%s to %s\n' "$key" "$val" "$DNF_CONF"
    else
      printf '%s=%s\n' "$key" "$val" | sudo tee -a "$DNF_CONF" >/dev/null
    fi
  fi
done

# --- 1. System update ------------------------------------------------------
info "Updating the system first…"
run sudo dnf upgrade --refresh -y

# --- 2. RPM Fusion (free + nonfree) ----------------------------------------
if pkg_installed rpmfusion-free-release && pkg_installed rpmfusion-nonfree-release; then
  info "RPM Fusion already enabled — skipping."
else
  info "Enabling RPM Fusion repositories…"
  run sudo dnf install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
  run sudo dnf upgrade --refresh -y
fi

# --- 3. Development tools & build essentials --------------------------------
info "Installing development tools and build essentials…"
# Group installs (compilers, headers, autotools, etc.)
run sudo dnf group install -y "development-tools" || \
  run sudo dnf group install -y "Development Tools" || true
run sudo dnf group install -y "c-development" || true

# Core dev packages (vim included alongside neovim)
run sudo dnf install -y \
  gcc gcc-c++ make cmake automake autoconf \
  git git-lfs \
  python3 python3-pip python3-virtualenv \
  golang \
  gdb valgrind \
  jq ripgrep fd-find fzf bat eza \
  tmux wget curl unzip tar \
  htop btop \
  vim-enhanced \
  openssl-devel readline-devel zlib-devel \
  ShellCheck

# --- 3a. lazygit (installed via Go) ----------------------------------------
# Built from source with 'go install' rather than the dnf package. Go was
# installed above (the 'golang' package). Binaries land in Go's bin dir, which
# we add to PATH via ~/.bashrc if it isn't already there.
GOBIN_DIR="$(go env GOBIN 2>/dev/null || true)"
[[ -z "$GOBIN_DIR" ]] && GOBIN_DIR="$(go env GOPATH 2>/dev/null || echo "$HOME/go")/bin"

if command -v lazygit &>/dev/null || [[ -x "$GOBIN_DIR/lazygit" ]]; then
  info "lazygit already installed — skipping."
elif [[ $DRY_RUN -eq 1 ]]; then
  info "[dry-run] go install github.com/jesseduffield/lazygit@latest (into $GOBIN_DIR)"
else
  info "Installing lazygit via 'go install' (this compiles from source)…"
  # Run as the normal user so it installs into the user's Go bin, not root's.
  go install github.com/jesseduffield/lazygit@latest || \
    warn "lazygit install via go failed — you can retry manually or use 'sudo dnf install lazygit'."
fi

# Ensure the Go bin dir is on PATH for future shells.
BASHRC="$HOME/.bashrc"
if [[ -f "$BASHRC" ]] && grep -q 'go env GOPATH\|/go/bin' "$BASHRC"; then
  info "Go bin directory already on PATH in ~/.bashrc."
elif [[ $DRY_RUN -eq 1 ]]; then
  info "[dry-run] Would add Go bin dir ($GOBIN_DIR) to PATH in ~/.bashrc."
else
  info "Adding Go bin directory to PATH in ~/.bashrc…"
  {
    printf '\n# Go-installed binaries (added by fedora-setup.sh)\n'
    # $PATH is intentionally left literal so it expands when the shell starts.
    # shellcheck disable=SC2016
    printf 'export PATH="$PATH:%s"\n' "$GOBIN_DIR"
  } >> "$BASHRC"
  warn "Open a new shell or run: export PATH=\"\$PATH:$GOBIN_DIR\"  (to use lazygit now)"
fi

# --- 3b. Git configuration -------------------------------------------------
GITCONFIG="$HOME/.gitconfig"
if [[ -f "$GITCONFIG" ]] && git config --global user.name &>/dev/null \
   && git config --global user.email &>/dev/null; then
  info "Git already configured (user.name and user.email set) — skipping."
elif [[ $DRY_RUN -eq 1 ]]; then
  info "[dry-run] Would prompt to configure git user.name/user.email."
elif ask "Would you like to configure git (user name/email) now?"; then
  # Pre-fill from any existing values so re-runs are non-destructive.
  existing_name="$(git config --global user.name || true)"
  existing_email="$(git config --global user.email || true)"

  read -rp "  Git user name${existing_name:+ [$existing_name]}: " git_name
  git_name="${git_name:-$existing_name}"
  read -rp "  Git email${existing_email:+ [$existing_email]}: " git_email
  git_email="${git_email:-$existing_email}"

  if [[ -n "$git_name" && -n "$git_email" ]]; then
    git config --global user.name "$git_name"
    git config --global user.email "$git_email"
    # A few sensible defaults (only set if not already present).
    git config --global init.defaultBranch    "$(git config --global init.defaultBranch || echo main)"
    git config --global pull.ff                "$(git config --global pull.ff || echo only)"
    git config --global color.ui               "$(git config --global color.ui || echo auto)"
    command -v nvim &>/dev/null && \
      git config --global core.editor "$(git config --global core.editor || echo nvim)"
    info "Git configured for $git_name <$git_email>."
  else
    warn "Name or email left blank — skipping git configuration."
  fi
else
  warn "Skipping git configuration."
fi

# --- 4. Neovim -------------------------------------------------------------
if pkg_installed neovim; then
  info "Neovim already installed — skipping package install."
else
  info "Installing Neovim…"
  run sudo dnf install -y neovim python3-neovim
fi


# --- 5. Brave browser ------------------------------------------------------
info "Installing Brave browser (official repo)…"
if ! command -v brave-browser &>/dev/null; then
  # Use Brave's official installer, which sets up the repo and GPG key.
  if [[ $DRY_RUN -eq 1 ]]; then
    printf '\033[1;35m[dry-run]\033[0m curl -fsS https://dl.brave.com/install.sh | sh\n'
  else
    curl -fsS https://dl.brave.com/install.sh | sh
  fi
else
  warn "Brave already installed — skipping."
fi

# --- 6. KVM / QEMU / libvirt virtualization stack ---------------------------
info "Installing virtualization (KVM/QEMU/libvirt) packages…"

# Check hardware virtualization is available (informational)
if grep -Eq 'vmx|svm' /proc/cpuinfo; then
  info "CPU virtualization extensions detected (VT-x/AMD-V). Good."
else
  warn "No VT-x/AMD-V detected in /proc/cpuinfo — check that virtualization is ENABLED in BIOS."
fi

run sudo dnf group install -y "virtualization" || true
run sudo dnf install -y \
  qemu-kvm libvirt virt-install virt-manager virt-viewer \
  libvirt-daemon-config-network libvirt-daemon-kvm \
  bridge-utils edk2-ovmf swtpm swtpm-tools \
  guestfs-tools libguestfs-tools

# Cockpit + its VM module (web UI at https://localhost:9090)
info "Installing Cockpit with the virtual-machines module…"
run sudo dnf install -y cockpit cockpit-machines
run sudo systemctl enable --now cockpit.socket

# Enable and start libvirt
info "Enabling libvirtd…"
run sudo systemctl enable --now libvirtd

# Add current user to libvirt & kvm groups (so you can manage VMs without root)
info "Adding $USERNAME to libvirt and kvm groups…"
run sudo usermod -aG libvirt,kvm "$USERNAME"

# Make the default libvirt network autostart
if sudo virsh net-info default &>/dev/null; then
  run sudo virsh net-autostart default || true
  run sudo virsh net-start default 2>/dev/null || true
fi

# --- 6b. NVIDIA proprietary drivers ----------------------------------------
# Uses the RPM Fusion akmod route (the recommended method on Fedora). The
# kernel module is built by akmods; allow a few minutes and reboot afterwards.
if lspci | grep -Eiq 'vga|3d|display' && lspci | grep -iq nvidia; then
  if pkg_installed akmod-nvidia; then
    info "NVIDIA drivers (akmod-nvidia) already installed — skipping."
  elif ask "An NVIDIA GPU was detected. Install the proprietary NVIDIA drivers?"; then
    if ! pkg_installed rpmfusion-nonfree-release; then
      err "RPM Fusion nonfree is required for NVIDIA drivers but isn't enabled. Skipping."
    else
      info "Installing NVIDIA drivers (akmod-nvidia + CUDA support)…"
      run sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda

      # --- Secure Boot / MOK handling -------------------------------------
      # If Secure Boot is enabled, the akmod-built NVIDIA kernel module must be
      # signed with a Machine Owner Key (MOK) that's enrolled in firmware, or
      # the module won't load at boot. We install the signing tools and, if
      # the RPM Fusion key isn't already enrolled, offer to enroll it.
      sb_state=""
      if command -v mokutil &>/dev/null; then
        sb_state="$(mokutil --sb-state 2>/dev/null || true)"
      fi
      if printf '%s' "$sb_state" | grep -qi "enabled"; then
        info "Secure Boot is ENABLED — NVIDIA module needs a signed/enrolled key."
        run sudo dnf install -y akmods kmodtool openssl mokutil

        MOK_KEY="/etc/pki/akmods/certs/public_key.der"
        already_enrolled=0
        # akmods ships a helper that enrolls its signing key.
        if command -v mokutil &>/dev/null && [[ -f "$MOK_KEY" ]]; then
          if mokutil --test-key "$MOK_KEY" 2>/dev/null | grep -qi "already enrolled"; then
            already_enrolled=1
          fi
        fi

        if [[ $already_enrolled -eq 1 ]]; then
          info "RPM Fusion / akmods MOK already enrolled — nothing to do."
        elif [[ $DRY_RUN -eq 1 ]]; then
          info "[dry-run] Would run kmodgenca and mokutil --import to enroll the akmods MOK."
        elif ask "Enroll the akmods signing key for Secure Boot now? (you'll set a one-time password used at next reboot)"; then
          # Generate the akmods CA if needed, then import it. mokutil will
          # prompt for a password that you must re-enter in the blue MOK
          # Manager screen on the NEXT reboot to complete enrollment.
          run sudo /usr/sbin/kmodgenca -a || true
          if [[ -f "$MOK_KEY" ]]; then
            run sudo mokutil --import "$MOK_KEY"
            warn "MOK import staged. On the NEXT reboot, choose 'Enroll MOK' and enter"
            warn "the password you just set. The NVIDIA module won't load until you do."
          else
            warn "Could not find $MOK_KEY — you may need to enroll the MOK manually."
          fi
        else
          warn "Skipped MOK enrollment. With Secure Boot on, the NVIDIA module may"
          warn "fail to load until the akmods key is enrolled (or disable Secure Boot)."
        fi
      elif [[ -n "$sb_state" ]]; then
        info "Secure Boot is disabled — no MOK enrollment needed."
      else
        warn "Could not determine Secure Boot state (mokutil unavailable). If Secure"
        warn "Boot is on, you may need to enroll the akmods MOK for NVIDIA to load."
      fi

      info "Triggering kernel module build (this can take a few minutes)…"
      run sudo akmods --force || true
      run sudo dracut --force || true
      warn "NVIDIA install done. REBOOT required. After reboot verify with: nvidia-smi"
      warn "Do not reboot until akmods has finished building (check: modinfo -F version nvidia)."
    fi
  else
    warn "Skipping NVIDIA driver installation."
  fi
else
  info "No NVIDIA GPU detected — skipping NVIDIA drivers."
fi

# --- 6c. GNOME keyboard shortcuts ------------------------------------------
# Only meaningful under a GNOME session with gsettings available.
if command -v gsettings &>/dev/null && [[ -n "${XDG_CURRENT_DESKTOP:-}" ]] \
   && printf '%s' "$XDG_CURRENT_DESKTOP" | grep -qi gnome; then
  info "Configuring GNOME keyboard shortcuts…"

  # Fix Alt+Tab to switch between individual windows (not app groups),
  # and Alt+` to switch within an app. Shift variants cycle backwards.
  run gsettings set org.gnome.desktop.wm.keybindings switch-windows "['<Alt>Tab']"
  run gsettings set org.gnome.desktop.wm.keybindings switch-windows-backward "['<Shift><Alt>Tab']"
  # Clear the application-based switcher so it doesn't shadow the window one.
  run gsettings set org.gnome.desktop.wm.keybindings switch-applications "[]"
  run gsettings set org.gnome.desktop.wm.keybindings switch-applications-backward "[]"
  info "Alt+Tab now switches individual windows."

  # Ctrl+T → open the default terminal. On Fedora 41+ (incl. 44) the default
  # GNOME terminal app is Ptyxis; fall back through other terminals if needed.
  term_cmd=""
  for t in ptyxis gnome-terminal kgx konsole xterm; do
    if command -v "$t" &>/dev/null; then term_cmd="$t"; break; fi
  done
  if [[ -z "$term_cmd" ]]; then
    warn "No terminal emulator found — installing Ptyxis (Fedora's default) for the Ctrl+T shortcut."
    run sudo dnf install -y ptyxis && term_cmd="ptyxis"
  fi
  if [[ -n "$term_cmd" ]]; then
    register_custom_keybinding "open-terminal" "Open Terminal" "$term_cmd" "<Control>t"
  fi

  # Super+E ("Windows key + E") → open the file manager, Windows-style.
  # Nautilus (GNOME Files) is Fedora Workstation's default file manager.
  fm_cmd=""
  for f in nautilus nemo dolphin thunar pcmanfm; do
    if command -v "$f" &>/dev/null; then fm_cmd="$f"; break; fi
  done
  if [[ -z "$fm_cmd" ]]; then
    warn "No file manager found — installing Nautilus for the Super+E shortcut."
    run sudo dnf install -y nautilus && fm_cmd="nautilus"
  fi
  if [[ -n "$fm_cmd" ]]; then
    register_custom_keybinding "open-file-explorer" "Open File Explorer" "$fm_cmd" "<Super>e"
  fi
else
  warn "Not a GNOME session (or gsettings missing) — skipping GNOME shortcut setup."
fi

# --- 6d. Developer fonts ---------------------------------------------------
# Fira Code, JetBrains Mono, and Google's Noto family (the Google fonts
# packaged in Fedora's repos).
info "Installing developer fonts…"
FONT_PKGS=(
  fira-code-fonts
  jetbrains-mono-fonts
  google-noto-sans-fonts
  google-noto-serif-fonts
  google-noto-emoji-fonts
)
missing_fonts=()
for f in "${FONT_PKGS[@]}"; do
  pkg_installed "$f" || missing_fonts+=("$f")
done
if [[ ${#missing_fonts[@]} -eq 0 ]]; then
  info "All developer fonts already installed — skipping."
else
  info "Installing: ${missing_fonts[*]}"
  run sudo dnf install -y "${missing_fonts[@]}"
  run sudo fc-cache -f
fi

# --- 6e. Podman ------------------------------------------------------------
if pkg_installed podman; then
  info "Podman already installed — skipping."
else
  info "Installing Podman (+ compose & docker-compat CLI)…"
  run sudo dnf install -y podman podman-compose podman-docker
fi

# --- 6f. GNOME Tweaks ------------------------------------------------------
if pkg_installed gnome-tweaks; then
  info "gnome-tweaks already installed — skipping."
else
  info "Installing gnome-tweaks…"
  run sudo dnf install -y gnome-tweaks
fi

# --- 6g. Snapper (Btrfs snapshots) -----------------------------------------
# Only meaningful on a Btrfs root (Fedora Workstation's default layout).
rootfs_type="$(findmnt -no FSTYPE / 2>/dev/null || echo unknown)"
if [[ "$rootfs_type" != "btrfs" ]]; then
  info "Root filesystem is '$rootfs_type' (not btrfs) — skipping snapper."
elif pkg_installed snapper && sudo snapper -c root list &>/dev/null; then
  info "Snapper already installed and configured for root — skipping."
elif [[ $DRY_RUN -eq 1 ]]; then
  info "[dry-run] Would install snapper and create a 'root' config for /."
else
  info "Installing snapper for Btrfs snapshots…"
  run sudo dnf install -y snapper python3-dnf-plugin-snapper
  # Create a config for the root subvolume if one doesn't exist yet.
  if ! sudo snapper -c root list &>/dev/null; then
    info "Creating snapper 'root' config for /…"
    run sudo snapper -c root create-config / || \
      warn "snapper create-config failed (a subvolume/.snapshots conflict is common on Fedora)."
  fi
  # Enable the periodic timers.
  run sudo systemctl enable --now snapper-timeline.timer || true
  run sudo systemctl enable --now snapper-cleanup.timer || true
fi

# --- 6h. Firmware updates --------------------------------------------------
# Uses fwupd/LVFS. Non-interactive; only applies updates the vendor published.
if command -v fwupdmgr &>/dev/null || pkg_installed fwupd; then
  info "Checking for firmware updates via fwupd/LVFS…"
  pkg_installed fwupd || run sudo dnf install -y fwupd
  run sudo fwupdmgr refresh --force || true
  if [[ $DRY_RUN -eq 1 ]]; then
    info "[dry-run] Would run: sudo fwupdmgr update"
  else
    # 'get-updates' exits non-zero when there's nothing to do; don't let that
    # abort the script.
    if sudo fwupdmgr get-updates &>/dev/null; then
      warn "Firmware updates available. Applying (may schedule a reboot)…"
      sudo fwupdmgr update -y || warn "Some firmware updates may need a manual reboot to apply."
    else
      info "No firmware updates available."
    fi
  fi
else
  info "Installing fwupd for firmware updates…"
  run sudo dnf install -y fwupd
  run sudo fwupdmgr refresh --force || true
  [[ $DRY_RUN -eq 1 ]] || sudo fwupdmgr update -y || warn "Firmware update step skipped/failed."
fi

# --- 7. Clone git repositories ---------------------------------------------
info "Cloning git repositories into $REPO_DIR …"
run mkdir -p "$REPO_DIR"

if [[ ${#REPOS[@]} -eq 0 ]]; then
  warn "No repos listed in the REPOS array — skipping clone step."
  warn "Edit this script and add your repo URLs to clone them."
elif [[ $DRY_RUN -eq 1 ]]; then
  for url in "${REPOS[@]}"; do
    printf '\033[1;35m[dry-run]\033[0m git clone %s (into %s)\n' "$url" "$REPO_DIR"
  done
else
  cd "$REPO_DIR"
  for url in "${REPOS[@]}"; do
    name="$(basename "$url" .git)"
    if [[ -d "$name/.git" ]]; then
      warn "$name already exists — pulling latest instead."
      ( cd "$name" && git pull --ff-only ) || warn "Pull failed for $name"
    else
      info "Cloning $name …"
      git clone "$url" || err "Clone failed for $url"
    fi
  done
fi

# --- Done ------------------------------------------------------------------
info "Setup complete!"
echo
echo "----------------------------------------------------------------------"
echo " NEXT STEPS / NOTES:"
echo "  * Log out and back in (or reboot) for the libvirt/kvm group changes"
echo "    to take effect — otherwise you'll need sudo for VM commands."
echo "  * Cockpit web UI: https://localhost:9090  (Virtual Machines tab)"
echo "  * Verify KVM:      virsh list --all   (should run without sudo after relogin)"
echo "  * If you used SSH git URLs, ensure your SSH key is added:"
echo "        ssh-keygen -t ed25519 -C \"you@example.com\""
echo "        cat ~/.ssh/id_ed25519.pub   # add to GitHub/GitLab"
echo "  * Editors: Neovim (config at ~/.config/nvim/init.lua) and classic vim."
echo "  * GNOME: Alt+Tab switches individual windows; Ctrl+T opens the terminal;"
echo "    Super+E ('Win'+E) opens the file manager."
echo "    (Log out/in if the shortcuts don't take effect immediately.)"
echo "  * Podman installed (docker-compat CLI available as 'docker')."
echo "  * lazygit installed via Go into your Go bin dir; open a new shell if"
echo "    'lazygit' isn't found yet (PATH was updated in ~/.bashrc)."
echo "  * Fonts: Fira Code, JetBrains Mono, Noto — select them in your terminal/editor."
echo "  * Snapper: if configured, snapshots run on a timer (snapper -c root list)."
echo "  * Firmware: re-run 'sudo fwupdmgr update' after a reboot if updates were staged."
echo "  * NVIDIA + Secure Boot: if you enrolled a MOK, complete it in the blue"
echo "    'MOK Manager' screen on next boot, then verify with: nvidia-smi"
echo "----------------------------------------------------------------------"
