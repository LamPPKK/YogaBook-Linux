#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/../.." && pwd)
source "$script_dir/lib/distro.sh"

source /etc/os-release
[[ "${ID:-}" == linuxmint ]] || {
  printf 'error: this installer is for Linux Mint; detected %s\n' "${ID:-unknown}" >&2
  exit 1
}

if [[ -z "${UBUNTU_CODENAME:-}" && "${ID_LIKE:-}" == *debian* ]]; then
    exec "$script_dir/install-debian.sh" "$@"
fi

exec "$script_dir/install-ubuntu.sh" "$@"
