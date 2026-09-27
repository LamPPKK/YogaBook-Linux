#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/../.." && pwd)
kernel_dir=${1:-"$repo_root/kernel"}
kernel_repository=${2:-${KERNEL_REPOSITORY:-https://github.com/jekhor/yogabook-linux-kernel.git}}
kernel_ref=${3:-${KERNEL_REF:-v6.18.x-yogabook}}
camera_series_url=${CAMERA_SERIES_URL:-https://patchew.org/linux/20260831180101.3109854-1-mauriziocasciano7@gmail.com/mbox}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

[[ ! -e "$kernel_dir" ]] || die "kernel directory already exists: $kernel_dir"

git clone --depth 1 --branch "$kernel_ref" "$kernel_repository" "$kernel_dir"
git -C "$kernel_dir" config user.name yogabook-ci
git -C "$kernel_dir" config user.email yogabook-ci@localhost

camera_mbox="$repo_root/camera-series.mbox"
curl --fail --location --retry 3 "$camera_series_url" -o "$camera_mbox"

if ! git -C "$kernel_dir" am --keep-non-patch "$camera_mbox"; then
  current_patch=$(git -C "$kernel_dir" am --show-current-patch=raw || true)
  if grep -q 'Subject: \[PATCH v5 06/16\] media: intel: ipu-bridge:' <<<"$current_patch"; then
    git -C "$kernel_dir" am --skip || true
  fi

  current_patch=$(git -C "$kernel_dir" am --show-current-patch=raw || true)
  if grep -q 'Subject: \[PATCH v5 16/16\] media: i2c: Add WV517S lens actuator driver' <<<"$current_patch"; then
    wv517s_patch="$repo_root/wv517s.patch"
    git -C "$kernel_dir" am --show-current-patch=diff >"$wv517s_patch"
    git -C "$kernel_dir" am --skip
    git -C "$kernel_dir" apply --reject --whitespace=nowarn "$wv517s_patch" || true
    if ! grep -q 'obj-$(CONFIG_VIDEO_WV517S) += wv517s.o' "$kernel_dir/drivers/media/i2c/Makefile"; then
      sed -i '/obj-$(CONFIG_VIDEO_WM8775) += wm8775.o/a obj-$(CONFIG_VIDEO_WV517S) += wv517s.o' \
        "$kernel_dir/drivers/media/i2c/Makefile"
    fi
    rm -f "$kernel_dir/drivers/media/i2c/Makefile.rej"
    git -C "$kernel_dir" add MAINTAINERS drivers/media/i2c
    if ! git -C "$kernel_dir" diff --cached --quiet; then
      git -C "$kernel_dir" commit -m 'media: i2c: Add WV517S lens actuator driver'
    fi
  fi

  git -C "$kernel_dir" apply "$repo_root/patches/camera/ipu-bridge-yogabook.patch"
fi

rm -f "$camera_mbox" "$repo_root/wv517s.patch"
