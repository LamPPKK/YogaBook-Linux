#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/../.." && pwd)

if [[ $EUID -ne 0 ]]; then
  if command -v doas >/dev/null; then
    exec doas -E "$0" "$@"
  fi
  exec sudo -E "$0" "$@"
fi

package_dir="."
while (($#)); do
  case "$1" in
    --package-dir) (($# >= 2)) || { printf 'error: --package-dir requires a directory\n' >&2; exit 2; }; package_dir=$2; shift 2 ;;
    -h|--help) printf 'Usage: install-alpine.sh [--package-dir DIR]\n\nProvide Alpine .apk packages built from the Alpine packaging scripts.\n'; exit 0 ;;
    *) printf 'error: unknown option: %s\n' "$1" >&2; exit 2 ;;
  esac
done

exec "$repo_root/install-yogabook.sh" --package-dir "$package_dir" --no-keyboard-layout
