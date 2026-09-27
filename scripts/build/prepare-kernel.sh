#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/../.." && pwd)
kernel_dir=${1:-"$repo_root/kernel"}
kernel_repository=${2:-${KERNEL_REPOSITORY:-https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git}}
kernel_ref=${3:-${KERNEL_REF:-v7.2.8}}
camera_series_url=${CAMERA_SERIES_URL:-https://patchew.org/linux/20260831180101.3109854-1-mauriziocasciano7@gmail.com/mbox}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

[[ ! -e "$kernel_dir" ]] || die "kernel directory already exists: $kernel_dir"

git clone --depth 1 --branch "$kernel_ref" "$kernel_repository" "$kernel_dir"
git -C "$kernel_dir" config user.name yogabook-ci
git -C "$kernel_dir" config user.email yogabook-ci@localhost

# Kernel 7.2 already contains the generic codec, sensor and Lenovo platform
# drivers. These files add the Yoga Book-specific board topology and the
# software-node resources needed to bind them on both Android and Windows
# firmware variants.
mkdir -p "$kernel_dir/sound/soc/intel/boards"
install -m 644 "$repo_root/patches/kernel/cht_yogabook.c" \
  "$kernel_dir/sound/soc/intel/boards/cht_yogabook.c"

if ! grep -Fq 'config SND_SOC_INTEL_CHT_YOGABOOK_MACH' \
    "$kernel_dir/sound/soc/intel/boards/Kconfig"; then
  git -C "$kernel_dir" apply --check \
    "$repo_root/patches/kernel/yogabook-audio-v7.patch" || \
    die "Yoga Book audio Kconfig patch does not apply to $kernel_ref"
  git -C "$kernel_dir" apply \
    "$repo_root/patches/kernel/yogabook-audio-v7.patch"
fi

if git -C "$kernel_dir" apply --check \
    "$repo_root/patches/kernel/yogabook-lenovo-v7.patch"; then
  git -C "$kernel_dir" apply \
    "$repo_root/patches/kernel/yogabook-lenovo-v7.patch"
fi

camera_mbox="$repo_root/camera-series.mbox"
wv517s_patch="$repo_root/wv517s.patch"
cleanup() {
  rm -f "$camera_mbox" "$wv517s_patch"
}
trap cleanup EXIT

curl --fail --location --retry 3 "$camera_series_url" -o "$camera_mbox"

if ! git -C "$kernel_dir" am --keep-non-patch "$camera_mbox"; then
  current_patch=$(git -C "$kernel_dir" am --show-current-patch=raw || true)
  if grep -q 'Subject: \[PATCH v5 06/16\] media: intel: ipu-bridge:' <<<"$current_patch"; then
    git -C "$kernel_dir" am --skip || true
  fi

  current_patch=$(git -C "$kernel_dir" am --show-current-patch=raw || true)
  if grep -q 'Subject: \[PATCH v5 16/16\] media: i2c: Add WV517S lens actuator driver' <<<"$current_patch"; then
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

fi

# Older Yoga Book branches stop before the IPU bridge hunk. Do not apply the
# compatibility patch after the complete v5 camera series: it would duplicate
# the INT3477/OVTI2740 entries and fail the build preparation step.
if ! grep -Fq 'IPU_SENSOR_CONFIG("INT3477", 1, 360000000)' \
    "$kernel_dir/drivers/media/pci/intel/ipu-bridge.c"; then
  git -C "$kernel_dir" apply --check \
    "$repo_root/patches/camera/ipu-bridge-yogabook.patch" || \
    die "Yoga Book IPU bridge patch does not apply to $kernel_ref"
  git -C "$kernel_dir" apply \
    "$repo_root/patches/camera/ipu-bridge-yogabook.patch"
fi
