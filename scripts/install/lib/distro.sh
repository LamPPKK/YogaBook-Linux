#!/usr/bin/env bash

# Print the Ubuntu artifact series that is compatible with the current host.
# Linux Mint 22.x is based on Ubuntu 24.04 (Noble), so it must use the
# Ubuntu 24.04 artifact rather than being mistaken for Ubuntu 22.x.
yogabook_ubuntu_artifact_version() {
  case "${ID:-}" in
    ubuntu)
      case "${VERSION_ID:-}" in
        24.04|24.04.*) printf '24.04\n' ;;
        26.04|26.04.*) printf '26.04\n' ;;
        *) return 1 ;;
      esac
      ;;
    linuxmint)
      case "${VERSION_ID:-}" in
        22|22.*)
          [[ "${UBUNTU_CODENAME:-}" == noble ]] || return 1
          printf '24.04\n'
          ;;
        *) return 1 ;;
      esac
      ;;
    *) return 1 ;;
  esac
}

# Return success for Debian stable/oldstable and LMDE releases that share the
# same Debian package base. Forky and Sid remain accepted for development use.
yogabook_debian_supported() {
  case "${ID:-}" in
    debian) ;;
    linuxmint)
      if [[ "${VERSION_ID:-}" == 7* && "${ID_LIKE:-}" == *debian* ]]; then
        return 0
      fi
      [[ "${ID_LIKE:-}" == *debian* ]] || return 1
      ;;
    *) return 1 ;;
  esac

  case "${VERSION_CODENAME:-}" in
    bookworm|trixie|forky|sid) return 0 ;;
    *) return 1 ;;
  esac
}
