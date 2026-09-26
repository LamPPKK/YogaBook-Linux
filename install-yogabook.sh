#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'EOF'
Usage: install-yogabook.sh [options]

Install Yoga Book packages from a directory containing downloaded artifacts.

Options:
  --package-dir DIR       Package directory (default: current directory)
  --keyboard-layout NAME  pc104 (default) or pc105
  --no-keyboard-layout    Do not change the touch-keyboard layout
  -h, --help              Show this help
EOF
}

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
need_root() {
  if [[ ${EUID} -ne 0 ]]; then
    exec sudo -E "$0" "$@"
  fi
}

package_dir="."
keyboard_layout="pc104"
configure_layout=1
if (($# == 1)) && [[ "$1" == "-h" || "$1" == "--help" ]]; then
  usage
  exit 0
fi
if [[ ${EUID} -ne 0 ]]; then
  exec sudo -E "$0" "$@"
fi
while (($#)); do
  case "$1" in
    --package-dir) (($# >= 2)) || die "--package-dir requires a directory"; package_dir=$2; shift 2 ;;
    --keyboard-layout) (($# >= 2)) || die "--keyboard-layout requires pc104 or pc105"; keyboard_layout=$2; shift 2 ;;
    --no-keyboard-layout) configure_layout=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done
[[ -d "$package_dir" ]] || die "package directory does not exist: $package_dir"
[[ "$keyboard_layout" == pc104 || "$keyboard_layout" == pc105 ]] || die "keyboard layout must be pc104 or pc105"

mapfile -t debs < <(find "$package_dir" -maxdepth 1 -type f -name '*.deb' -print | sort)
mapfile -t rpms < <(find "$package_dir" -maxdepth 1 -type f -name '*.rpm' -print | sort)
mapfile -t pacmans < <(find "$package_dir" -maxdepth 1 -type f -name '*.pkg.tar.*' -print | sort)
mapfile -t apks < <(find "$package_dir" -maxdepth 1 -type f -name '*.apk' -print | sort)
(( ${#debs[@]} + ${#rpms[@]} + ${#pacmans[@]} + ${#apks[@]} > 0 )) || die "no .deb, .rpm, .pkg.tar.* or .apk packages found in $package_dir"

if ((${#debs[@]})); then
  command -v apt-get >/dev/null || die "apt-get is required to install .deb packages"
  apt-get update
  dpkg -i "${debs[@]}" || apt-get -f install -y
elif ((${#pacmans[@]})) && command -v pacman >/dev/null; then
  pacman -U --noconfirm "${pacmans[@]}"
elif ((${#rpms[@]})) && command -v dnf >/dev/null; then
  dnf install -y "${rpms[@]}"
elif ((${#rpms[@]})) && command -v zypper >/dev/null; then
  zypper --non-interactive install "${rpms[@]}"
elif ((${#pacmans[@]})); then
  die "pacman is required to install Arch packages"
elif ((${#rpms[@]})); then
  die "dnf or zypper is required to install RPM packages"
elif ((${#apks[@]})); then
  command -v apk >/dev/null || die "apk is required to install APK packages"
  apk add --allow-untrusted "${apks[@]}"
fi

if ((configure_layout)); then
  layout_dir=/etc/touch_keyboard/layouts
  layout_file="$layout_dir/YB1-X9x-$keyboard_layout.csv"
  if [[ -f "$layout_file" ]]; then
    ln -sfn "$layout_file" /etc/touch_keyboard/layout.csv
    if command -v systemctl >/dev/null && systemctl list-unit-files touch-keyboard-handler.service >/dev/null 2>&1; then
      systemctl try-restart touch-keyboard-handler.service || true
    fi
  else
    printf 'warning: touch-keyboard layouts not found; leaving keyboard layout unchanged\n' >&2
  fi
fi

printf 'Yoga Book packages installed successfully. Reboot before testing the new kernel.\n'
