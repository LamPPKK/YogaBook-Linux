#!/usr/bin/env bash
set -Eeuo pipefail

YOGABOOK_REPOSITORY=${YOGABOOK_REPOSITORY:-LamPPKK/YogaBook-Linux}
YOGABOOK_API=${YOGABOOK_API:-https://api.github.com/repos/$YOGABOOK_REPOSITORY}

github_curl() {
  local auth=()
  if [[ -n ${GH_TOKEN:-} ]]; then
    auth=(-H "Authorization: Bearer $GH_TOKEN")
  fi
  curl --fail --location --retry 3 \
    -H 'Accept: application/vnd.github+json' \
    -H 'X-GitHub-Api-Version: 2022-11-28' \
    "${auth[@]}" "$@"
}

require_download_tools() {
  command -v curl >/dev/null || { printf 'error: curl is required\n' >&2; exit 1; }
  command -v jq >/dev/null || { printf 'error: jq is required for GitHub artifact downloads\n' >&2; exit 1; }
  command -v unzip >/dev/null || { printf 'error: unzip is required for GitHub artifact downloads\n' >&2; exit 1; }
}

latest_successful_run() {
  local workflow=$1
  github_curl "$YOGABOOK_API/actions/workflows/$workflow/runs?branch=master&status=success&per_page=20" \
    | jq -er '.workflow_runs | map(select(.conclusion == "success")) | .[0].id'
}

download_artifact() {
  local run_id=$1 pattern=$2 destination=$3
  local artifact_id
  artifact_id=$(github_curl "$YOGABOOK_API/actions/runs/$run_id/artifacts?per_page=100" \
    | jq -er --arg pattern "$pattern" \
      '.artifacts | map(select(.expired == false and (.name | test($pattern)))) | .[0].id')
  mkdir -p "$destination"
  github_curl "$YOGABOOK_API/actions/artifacts/$artifact_id/zip" -o "$destination/artifact.zip"
  unzip -q -o "$destination/artifact.zip" -d "$destination"
  rm -f "$destination/artifact.zip"
}

download_userspace_debs() {
  local run_id=$1 destination=$2
  local artifact_id artifact_name
  mkdir -p "$destination"
  while IFS=$'\t' read -r artifact_id artifact_name; do
    [[ -n "$artifact_id" ]] || continue
    github_curl "$YOGABOOK_API/actions/artifacts/$artifact_id/zip" \
      -o "$destination/$artifact_name.zip"
    unzip -q -o "$destination/$artifact_name.zip" -d "$destination"
    rm -f "$destination/$artifact_name.zip"
  done < <(
    github_curl "$YOGABOOK_API/actions/runs/$run_id/artifacts?per_page=100" \
      | jq -r '.artifacts[] | select(.expired == false and (.name | test("^yogabook-.*-deb-"))) | [.id, .name] | @tsv'
  )
}

download_latest_ubuntu() {
  local version=$1 destination=$2
  require_download_tools
  local kernel_run userspace_run
  kernel_run=$(latest_successful_run build-kernel.yml)
  userspace_run=$(latest_successful_run build-userspace-debs.yml)
  download_artifact "$kernel_run" "^yogabook-kernel-ubuntu-${version}-" "$destination"
  download_userspace_debs "$userspace_run" "$destination"
}

download_latest_fedora() {
  local destination=$1
  require_download_tools
  download_artifact "$(latest_successful_run build-native-packages.yml)" \
    '^yogabook-kernel-fedora-' "$destination"
}

download_latest_arch() {
  local destination=$1
  require_download_tools
  download_artifact "$(latest_successful_run build-native-packages.yml)" \
    '^yogabook-kernel-arch-' "$destination"
}
