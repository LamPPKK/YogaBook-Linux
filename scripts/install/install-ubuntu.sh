#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/../.." && pwd)
source "$script_dir/lib/github-actions.sh"

source /etc/os-release
version_id=${VERSION_ID:-}
[[ "$version_id" == 24.04 || "$version_id" == 26.04 ]] || {
  printf 'error: this installer supports Ubuntu 24.04 and 26.04; detected %s\n' "$version_id" >&2
  exit 1
}

package_dir=""
keyboard_args=()
while (($#)); do
  case "$1" in
    --package-dir) (($# >= 2)) || { printf 'error: --package-dir requires a directory\n' >&2; exit 2; }; package_dir=$2; shift 2 ;;
    --keyboard-layout) (($# >= 2)) || { printf 'error: --keyboard-layout requires pc104 or pc105\n' >&2; exit 2; }; keyboard_args+=(--keyboard-layout "$2"); shift 2 ;;
    --no-keyboard-layout) keyboard_args+=(--no-keyboard-layout); shift ;;
    -h|--help) printf 'Usage: install-ubuntu.sh [--package-dir DIR] [--keyboard-layout pc104|pc105] [--no-keyboard-layout]\n'; exit 0 ;;
    *) printf 'error: unknown option: %s\n' "$1" >&2; exit 2 ;;
  esac
done

temporary_dir=""
if [[ -z "$package_dir" ]]; then
  temporary_dir=$(mktemp -d)
  trap 'rm -rf "$temporary_dir"' EXIT
  download_latest_ubuntu "$version_id" "$temporary_dir"
  package_dir=$temporary_dir
fi

exec "$repo_root/install-yogabook.sh" --package-dir "$package_dir" "${keyboard_args[@]}"
