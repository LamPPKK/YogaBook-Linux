#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'EOF'
Usage: build-userspace-deb.sh NAME REPOSITORY REF OUTPUT_DIR
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

(( $# == 4 )) || { usage >&2; exit 2; }
name=$1
repository=${2%.git}
ref=$3
output_dir=$(mkdir -p "$4" && cd -- "$4" && pwd)
work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT

archive_url="$repository/archive/refs/heads/$ref.tar.gz"
curl --fail --location --retry 3 "$archive_url" -o "$work_dir/source.tar.gz"
tar -xzf "$work_dir/source.tar.gz" -C "$work_dir"
source_dir=$(find "$work_dir" -mindepth 1 -maxdepth 1 -type d -print -quit)
[[ -n "$source_dir" ]] || die "could not find extracted source directory"
mv "$source_dir" "$work_dir/$name"
source_dir="$work_dir/$name"

git ls-remote "$repository" "refs/heads/$ref" | awk '{print $1}' >"$source_dir/SOURCE_COMMIT"
[[ -s "$source_dir/SOURCE_COMMIT" ]] || die "could not resolve source commit for $repository:$ref"

(cd "$source_dir" && dpkg-buildpackage -b -us -uc)
shopt -s nullglob
debs=("$work_dir"/*.deb)
((${#debs[@]})) || die "package build did not produce a Debian package"
cp "${debs[@]}" "$output_dir/"
cp "$source_dir/SOURCE_COMMIT" "$output_dir/"
metadata=("$output_dir"/*.deb "$output_dir/SOURCE_COMMIT")
sha256sum "${metadata[@]}" >"$output_dir/SHA256SUMS"
