#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/../.." && pwd)

usage() {
  cat <<'EOF'
Usage: build-kernel.sh MODE KERNEL_DIR OUTPUT_DIR [LOCAL_VERSION]

MODE:
  deb          Build Debian kernel packages.
  rpm          Build Fedora/RPM kernel packages.
  arch         Build an Arch-compatible kernel and modules archive.
  chromiumos   Build a generic ChromiumOS-compatible kernel and modules archive.
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

(( $# >= 3 && $# <= 4 )) || { usage >&2; exit 2; }
mode=$1
kernel_dir=$(cd -- "$2" && pwd)
output_dir=$(mkdir -p "$3" && cd -- "$3" && pwd)
local_version=${4:-${LOCAL_VERSION:--yogabook}}
jobs=${JOBS:-$(nproc)}

case "$mode" in
  deb)
    make -C "$kernel_dir" yogabook_defconfig
    make -C "$kernel_dir" LOCALVERSION="$local_version" -j"$jobs"
    make -C "$kernel_dir" LOCALVERSION="$local_version" bindeb-pkg -j1
    shopt -s nullglob
    debs=("$repo_root"/*.deb)
    ((${#debs[@]})) || die "kernel build did not produce Debian packages"
    cp "${debs[@]}" "$output_dir/"
    ;;
  rpm)
    make -C "$kernel_dir" yogabook_defconfig
    make -C "$kernel_dir" LOCALVERSION="$local_version" -j"$jobs"
    make -C "$kernel_dir" LOCALVERSION="$local_version" binrpm-pkg -j"$jobs"
    shopt -s nullglob
    rpms=("$kernel_dir"/rpmbuild/RPMS/*/*.rpm)
    ((${#rpms[@]})) || die "kernel build did not produce RPM packages"
    cp "${rpms[@]}" "$output_dir/"
    ;;
  arch)
    make -C "$kernel_dir" yogabook_defconfig
    make -C "$kernel_dir" LOCALVERSION="$local_version" -j"$jobs"
    make -C "$kernel_dir" LOCALVERSION="$local_version" \
      INSTALL_MOD_PATH="$kernel_dir/package" modules_install
    install -Dm644 "$kernel_dir/arch/x86/boot/bzImage" "$output_dir/vmlinuz-yogabook"
    tar -C "$kernel_dir/package" -czf "$output_dir/yogabook-modules.tar.gz" lib/modules
    ;;
  chromiumos)
    make -C "$kernel_dir" x86_64_defconfig
    make -C "$kernel_dir" LOCALVERSION="$local_version" -j"$jobs"
    modules_dir="$kernel_dir/../chromiumos-modules"
    make -C "$kernel_dir" INSTALL_MOD_PATH="$modules_dir" modules_install
    install -Dm644 "$kernel_dir/arch/x86/boot/bzImage" "$output_dir/vmlinuz-yogabook-chromiumos"
    tar -C "$modules_dir" -czf "$output_dir/yogabook-chromiumos-modules.tar.gz" lib/modules
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

artifacts=()
while IFS= read -r -d '' artifact; do
  artifacts+=("$artifact")
done < <(find "$output_dir" -maxdepth 1 -type f ! -name SHA256SUMS -print0)
((${#artifacts[@]})) || die "no build artifacts found in $output_dir"
sha256sum "${artifacts[@]}" >"$output_dir/SHA256SUMS"
