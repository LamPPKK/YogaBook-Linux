#!/usr/bin/env bash
set -Eeuo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
source "$repo_root/scripts/install/lib/distro.sh"

assert_eq() {
  local expected=$1 actual=$2 label=$3
  [[ "$expected" == "$actual" ]] || {
    printf 'FAIL: %s: expected %s, got %s\n' "$label" "$expected" "$actual" >&2
    exit 1
  }
}

ID=ubuntu VERSION_ID=24.04
assert_eq 24.04 "$(yogabook_ubuntu_artifact_version)" 'Ubuntu 24.04'

ID=ubuntu VERSION_ID=26.04
assert_eq 26.04 "$(yogabook_ubuntu_artifact_version)" 'Ubuntu 26.04'

ID=linuxmint VERSION_ID=22.3 UBUNTU_CODENAME=noble
assert_eq 24.04 "$(yogabook_ubuntu_artifact_version)" 'Linux Mint 22.3'

ID=debian VERSION_CODENAME=trixie
yogabook_debian_supported

ID=linuxmint ID_LIKE='debian ubuntu' VERSION_CODENAME=trixie
yogabook_debian_supported

ID=linuxmint ID_LIKE=debian VERSION_ID=7 VERSION_CODENAME=gigi
yogabook_debian_supported

if ID=linuxmint VERSION_ID=21.3 UBUNTU_CODENAME=jammy yogabook_ubuntu_artifact_version; then
  printf 'FAIL: unsupported Linux Mint release was accepted\n' >&2
  exit 1
fi

printf 'PASS: distro compatibility detection\n'
