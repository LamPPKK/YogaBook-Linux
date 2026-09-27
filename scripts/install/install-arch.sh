#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/../.." && pwd)
source "$script_dir/lib/github-actions.sh"

source /etc/os-release
[[ "${ID:-}" == arch || "${ID_LIKE:-}" == *arch* ]] || {
  printf 'error: this installer is for Arch/Manjaro-compatible systems\n' >&2
  exit 1
}

if [[ $EUID -ne 0 ]]; then
  exec sudo -E "$0" "$@"
fi

package_dir=""
while (($#)); do
  case "$1" in
    --package-dir) (($# >= 2)) || { printf 'error: --package-dir requires a directory\n' >&2; exit 2; }; package_dir=$2; shift 2 ;;
    -h|--help) printf 'Usage: install-arch.sh [--package-dir DIR]\n\nWithout --package-dir, the latest Arch kernel artifact is downloaded from LamPPKK/YogaBook-Linux.\n'; exit 0 ;;
    *) printf 'error: unknown option: %s\n' "$1" >&2; exit 2 ;;
  esac
done

temporary_dir=""
if [[ -z "$package_dir" ]]; then
  temporary_dir=$(mktemp -d)
  trap 'rm -rf "$temporary_dir"' EXIT
  download_latest_arch "$temporary_dir"
  package_dir=$temporary_dir
fi

if find "$package_dir" -maxdepth 1 -type f -name '*.pkg.tar.*' -print -quit | grep -q .; then
  exec "$repo_root/install-yogabook.sh" --package-dir "$package_dir"
fi

kernel_image=$(find "$package_dir" -maxdepth 1 -type f -name 'vmlinuz-yogabook' -print -quit)
modules_archive=$(find "$package_dir" -maxdepth 1 -type f -name 'yogabook-modules.tar.gz' -print -quit)
[[ -n "$kernel_image" && -n "$modules_archive" ]] || {
  printf 'error: expected vmlinuz-yogabook and yogabook-modules.tar.gz\n' >&2
  exit 1
}

install -Dm644 "$kernel_image" /boot/vmlinuz-yogabook
tar -xzf "$modules_archive" -C /
module_version=$(tar -tzf "$modules_archive" | sed -n 's#^lib/modules/\([^/]*\)/.*#\1#p' | head -n 1)
[[ -n "$module_version" ]] && depmod -a "$module_version"

if command -v mkinitcpio >/dev/null && [[ -n "$module_version" ]]; then
  mkinitcpio -k "$module_version" -g "/boot/initramfs-$module_version.img"
elif command -v dracut >/dev/null && [[ -n "$module_version" ]]; then
  dracut --force "/boot/initramfs-$module_version.img" "$module_version"
fi

if command -v update-grub >/dev/null; then
  update-grub
elif command -v grub-mkconfig >/dev/null && [[ -d /boot/grub ]]; then
  grub-mkconfig -o /boot/grub/grub.cfg
fi

printf 'Yoga Book Arch kernel installed successfully. Reboot to use it.\n'
