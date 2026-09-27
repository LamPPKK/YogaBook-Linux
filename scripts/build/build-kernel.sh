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

The Yoga Book 7.2 configuration is merged from configs/yogabook-7.2.config.
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
local_version=${4:-${LOCAL_VERSION:--yogabook7.2}}
jobs=${JOBS:-$(nproc)}
kernel_config=${KERNEL_CONFIG:-"$repo_root/configs/yogabook-7.2.config"}

configure_kernel() {
  [[ -r "$kernel_config" ]] || die "kernel config fragment not found: $kernel_config"
  make -C "$kernel_dir" x86_64_defconfig
  "$kernel_dir/scripts/kconfig/merge_config.sh" -m -O "$kernel_dir" \
    "$kernel_dir/.config" "$kernel_config"
  make -C "$kernel_dir" olddefconfig
}

case "$mode" in
  deb)
    configure_kernel
    make -C "$kernel_dir" LOCALVERSION="$local_version" -j"$jobs"
    make -C "$kernel_dir" LOCALVERSION="$local_version" bindeb-pkg -j1
    shopt -s nullglob
    debs=("$repo_root"/*.deb)
    ((${#debs[@]})) || die "kernel build did not produce Debian packages"
    cp "${debs[@]}" "$output_dir/"
    ;;
  rpm)
    configure_kernel
    make -C "$kernel_dir" LOCALVERSION="$local_version" -j"$jobs"
    make -C "$kernel_dir" LOCALVERSION="$local_version" binrpm-pkg -j"$jobs"
    shopt -s nullglob
    rpms=("$kernel_dir"/rpmbuild/RPMS/*/*.rpm)
    ((${#rpms[@]})) || die "kernel build did not produce RPM packages"
    cp "${rpms[@]}" "$output_dir/"
    ;;
  arch)
    configure_kernel
    make -C "$kernel_dir" LOCALVERSION="$local_version" -j"$jobs"
    make -C "$kernel_dir" LOCALVERSION="$local_version" \
      INSTALL_MOD_PATH="$kernel_dir/package" modules_install
    install -Dm644 "$kernel_dir/arch/x86/boot/bzImage" "$output_dir/vmlinuz-yogabook"
    tar -C "$kernel_dir/package" -czf "$output_dir/yogabook-modules.tar.gz" lib/modules
    ;;
  chromiumos)
    configure_kernel
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
