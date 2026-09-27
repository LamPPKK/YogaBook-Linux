#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/../.." && pwd)
source "$script_dir/lib/github-actions.sh"

source /etc/os-release
case "${VERSION_CODENAME:-}" in
  bookworm|trixie|forky|sid) ;;
  *) printf 'error: this installer supports Debian Bookworm, Trixie, Forky and Sid\n' >&2; exit 1 ;;
esac

package_dir=""
keyboard_args=()
while (($#)); do
  case "$1" in
    --package-dir) (($# >= 2)) || { printf 'error: --package-dir requires a directory\n' >&2; exit 2; }; package_dir=$2; shift 2 ;;
    --keyboard-layout) (($# >= 2)) || { printf 'error: --keyboard-layout requires pc104 or pc105\n' >&2; exit 2; }; keyboard_args+=(--keyboard-layout "$2"); shift 2 ;;
    --no-keyboard-layout) keyboard_args+=(--no-keyboard-layout); shift ;;
    -h|--help) printf 'Usage: install-debian.sh [--package-dir DIR] [--keyboard-layout pc104|pc105] [--no-keyboard-layout]\n'; exit 0 ;;
    *) printf 'error: unknown option: %s\n' "$1" >&2; exit 2 ;;
  esac
done

temporary_dir=""
if [[ -z "$package_dir" ]]; then
  temporary_dir=$(mktemp -d)
  trap 'rm -rf "$temporary_dir"' EXIT
  kernel_run=$(latest_successful_run build-kernel.yml)
  userspace_run=$(latest_successful_run build-userspace-debs.yml)
  download_artifact "$kernel_run" '^yogabook-kernel-ubuntu-24.04-' "$temporary_dir"
  download_userspace_debs "$userspace_run" "$temporary_dir"
  package_dir=$temporary_dir
fi

exec "$repo_root/install-yogabook.sh" --package-dir "$package_dir" "${keyboard_args[@]}"
