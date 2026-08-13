#!/usr/bin/env bash

set -euo pipefail

backup_once() {
  local file=$1
  local backup="${file}.before-goodix53x5"

  if [[ -e $file && ! -e $backup ]]; then
    sudo cp -a -- "$file" "$backup"
  fi
}

prepend_pam_module() {
  local file=$1
  local line=$2

  if ! sudo grep -Fq 'pam_fprintd.so' "$file"; then
    backup_once "$file"
    sudo sed -i "1i $line" "$file"
  fi
}

if ! fprintd-list "$USER" | grep -Fq 'Goodix HTK32 Fingerprint Sensor'; then
  printf 'fprintd cannot open the Goodix HTK32 reader.\n' >&2
  exit 1
fi

prepend_pam_module /etc/pam.d/sudo 'auth    sufficient pam_fprintd.so'

if [[ -e /etc/pam.d/polkit-1 ]]; then
  prepend_pam_module /etc/pam.d/polkit-1 'auth      sufficient pam_fprintd.so'
else
  pam_file=$(mktemp)
  trap 'rm -f "$pam_file"' EXIT
  printf '%s\n' \
    'auth      sufficient pam_fprintd.so' \
    'auth      required pam_unix.so' \
    '' \
    'account   required pam_unix.so' \
    'password  required pam_unix.so' \
    'session   required pam_unix.so' >"$pam_file"
  sudo install -m 0644 "$pam_file" /etc/pam.d/polkit-1
fi

hyprlock_config="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprlock.conf"

if [[ -e $hyprlock_config ]]; then
  hyprlock_backup="${hyprlock_config}.before-goodix53x5"
  if [[ ! -e $hyprlock_backup ]]; then
    cp -a -- "$hyprlock_config" "$hyprlock_backup"
  fi

  if grep -Eq '^[[:space:]]*fingerprint:enabled[[:space:]]*=' "$hyprlock_config"; then
    sed -i -E 's/^([[:space:]]*fingerprint:enabled[[:space:]]*=).*/\1 true/' "$hyprlock_config"
  else
    printf 'Hyprlock has no fingerprint:enabled setting. PAM is configured, but Hyprlock was not changed.\n' >&2
  fi
fi

if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
  hyprctl reload
  hyprctl configerrors
fi

printf 'Fingerprint authentication is enabled for sudo, Polkit, and supported Hyprlock configurations.\n'
