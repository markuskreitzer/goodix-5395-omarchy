#!/usr/bin/env bash

set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_dir"

if ! lsusb -d 27c6:5395 >/dev/null; then
  printf 'Goodix 27c6:5395 was not found.\n' >&2
  exit 1
fi

makepkg --syncdeps --needed --cleanbuild
package_path=$(makepkg --packagelist)

if [[ ! -f $package_path ]]; then
  printf 'Package was not created: %s\n' "$package_path" >&2
  exit 1
fi

sudo pacman -U --confirm "$package_path"
sudo systemctl restart fprintd.service
fprintd-list "$USER"
