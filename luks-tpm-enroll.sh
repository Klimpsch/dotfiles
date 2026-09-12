#!/usr/bin/env bash
#
# luks-tpm-enroll.sh — set up TPM2 auto-unlock for a LUKS-encrypted Fedora root
#
# WHAT IT DOES
#   Enrolls your machine's TPM2 chip as an additional way to unlock the LUKS
#   volume, so it unlocks automatically at boot on THIS machine, in its
#   trusted state — no passphrase typing on every boot.
#
# WHAT IT DOES NOT DO
#   It does NOT remove your passphrase. Your passphrase stays as a fallback
#   and you MUST keep it. If the TPM ever refuses (after a BIOS update,
#   Secure Boot change, or hardware swap), you type the passphrase that boot
#   and re-run this script.
#
# USAGE
#   sudo ./luks-tpm-enroll.sh
#
# ---------------------------------------------------------------------------

set -euo pipefail

info()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
err()   { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; }

if [[ $EUID -ne 0 ]]; then
  err "Run this with sudo:  sudo $0"
  exit 1
fi

# --- 1. Verify a TPM2 device exists ----------------------------------------
info "Checking for a TPM2 device…"
if [[ ! -e /sys/class/tpm/tpm0 ]]; then
  err "No TPM device found at /sys/class/tpm/tpm0."
  err "Check that TPM/fTPM is ENABLED in your BIOS, then reboot and retry."
  exit 1
fi
info "TPM device present."

# --- 2. Ensure the tools are installed -------------------------------------
info "Installing TPM2 tooling if needed…"
dnf install -y systemd-cryptsetup tpm2-tools >/dev/null 2>&1 || \
  dnf install -y tpm2-tools >/dev/null 2>&1 || true

# --- 3. Find the LUKS partition --------------------------------------------
info "Detecting the LUKS partition…"
LUKS_PART="$(blkid -t TYPE=crypto_LUKS -o device | head -n1 || true)"

if [[ -z "${LUKS_PART:-}" ]]; then
  err "Could not auto-detect a crypto_LUKS partition."
  err "Run 'lsblk -f', find the crypto_LUKS device, and set it manually:"
  err "    sudo LUKS_PART=/dev/nvme0n1p3 $0"
  exit 1
fi
# Allow override via environment
LUKS_PART="${LUKS_PART}"
info "LUKS partition: $LUKS_PART"
echo
lsblk -f "$LUKS_PART"
echo
read -rp "Is this the correct LUKS partition? [y/N] " ok
[[ "$ok" =~ ^[Yy]$ ]] || { err "Aborted. Set LUKS_PART=... manually and re-run."; exit 1; }

# --- 4. Show current key slots (so you can confirm passphrase slot stays) ---
info "Current LUKS key slots:"
cryptsetup luksDump "$LUKS_PART" | grep -A1 "Keyslots:" || true
warn "Your passphrase slot must remain. This script only ADDS a TPM slot."

# --- 5. Enroll the TPM2 -----------------------------------------------------
# PCR 7 binds the key to Secure Boot state. It's the most robust common choice
# (survives normal kernel updates; re-enroll needed after firmware/SB changes).
info "Enrolling TPM2 (bound to PCR 7 = Secure Boot state)…"
warn "You will be asked for your EXISTING LUKS passphrase once."
systemd-cryptenroll "$LUKS_PART" --tpm2-device=auto --tpm2-pcrs=7

# --- 6. Update /etc/crypttab so boot tries the TPM -------------------------
info "Updating /etc/crypttab to use the TPM at boot…"
cp /etc/crypttab "/etc/crypttab.bak.$(date +%s)"

# Add tpm2-device=auto to the options field of the matching line.
UUID="$(blkid -s UUID -o value "$LUKS_PART")"
if grep -q "$UUID" /etc/crypttab; then
  # append option if not already present on that line
  if ! grep -q "tpm2-device=auto" /etc/crypttab; then
    sed -i "/$UUID/ s/\$/,tpm2-device=auto/" /etc/crypttab
    # tidy: if the options field was 'none', replace 'none,tpm2' -> 'tpm2'
    sed -i "s/none,tpm2-device=auto/tpm2-device=auto/" /etc/crypttab
  else
    warn "crypttab already references tpm2-device — leaving as is."
  fi
else
  warn "No crypttab line matched UUID $UUID."
  warn "You may need to add one manually. Current crypttab:"
  cat /etc/crypttab
fi

info "New /etc/crypttab:"
cat /etc/crypttab

# --- 7. Rebuild the initramfs ----------------------------------------------
info "Regenerating initramfs (dracut --force)…"
dracut --force

# --- Done ------------------------------------------------------------------
echo
info "TPM2 enrollment complete."
echo "----------------------------------------------------------------------"
echo " REBOOT to test — it should unlock without a passphrase prompt."
echo
echo " IF it still asks for a passphrase: the TPM enrollment didn't take on"
echo " boot; type your passphrase, then check 'sudo systemd-cryptenroll"
echo " $LUKS_PART' shows a tpm2 slot and that /etc/crypttab has"
echo " tpm2-device=auto."
echo
echo " KEEP YOUR PASSPHRASE. After any BIOS update or Secure Boot change the"
echo " TPM will stop auto-unlocking — type the passphrase and re-run this"
echo " script to re-enroll."
echo "----------------------------------------------------------------------"
