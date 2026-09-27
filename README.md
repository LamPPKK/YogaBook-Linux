# Yoga Book Linux

Linux support for Lenovo Yoga Book tablets:

- YB1-X90F/L — Android models
- YB1-X91F/L — Windows models

The project contains the Yoga Book kernel, touch keyboard support, audio
configuration, sensor support and distribution packaging information.

## Current status

The default kernel is based on the `v6.18.x-yogabook` branch. Most hardware
support is available through the Yoga Book kernel patches and the upstream
Linux kernel.

Known limitations include:

- Camera support is experimental and is built from the Yoga Book v5 camera
  series (OV2740, OV8858, AtomISP/CSI-2 and WV517S).
- LTE may not work on L variants.
- Audio still requires the Yoga Book-specific configuration.
- Suspend, charging while powered on, screen brightness, stylus axes and
  microphone channel mapping may vary by device firmware and desktop environment.

Please include the device model and `dmesg`/`journalctl` output when reporting
an issue: <https://github.com/LamPPKK/YogaBook-Linux/issues>.

## Maintained source mirrors

The related source repositories are mirrored under the `LamPPKK` account so
the superproject and its build jobs use your GitHub organization. The mirror
set includes the touch keyboard, ALSA UCM, support service, IIO sensor proxy,
live CD, Android kernel sources and ProductionKernelQuilts. `ps4-linux` is a
separate repository and is intentionally not a submodule or build input here.

## Installation

The easiest approach is to install a distribution supported by the package
repositories, then install these packages:

- `linux-image-yogabook`
- `linux-headers-yogabook` (optional)
- `touch-keyboard`
- `yogabook-support`
- `alsa-ucm-conf-yogabook`

Available package targets currently include Ubuntu 24.04/26.04, Debian
Bookworm/Trixie/Forky/Sid, Fedora/RHEL-compatible systems, Arch/Manjaro and
Alpine Linux. Ubuntu, Fedora and Arch packages are built by GitHub Actions in
this repository and published as checksummed artifacts.

Package repositories and build scripts are maintained here:

- Build helpers: <https://github.com/LamPPKK/YogaBook-Linux/tree/master/scripts/build>
- Ubuntu installer: <https://github.com/LamPPKK/YogaBook-Linux/blob/master/scripts/install/install-ubuntu.sh>
- Debian installer: <https://github.com/LamPPKK/YogaBook-Linux/blob/master/scripts/install/install-debian.sh>
- Fedora/RHEL installer: <https://github.com/LamPPKK/YogaBook-Linux/blob/master/scripts/install/install-fedora.sh>
- Arch/Manjaro installer: <https://github.com/LamPPKK/YogaBook-Linux/blob/master/scripts/install/install-arch.sh>
- Alpine installer: <https://github.com/LamPPKK/YogaBook-Linux/blob/master/scripts/install/install-alpine.sh>
- GitHub Actions packages: <https://github.com/LamPPKK/YogaBook-Linux/actions>

For Debian or Ubuntu, install packages downloaded from this repository with:

```sh
sudo apt install ./linux-image-yogabook*.deb ./touch-keyboard*.deb \
  ./yogabook-support*.deb ./alsa-ucm-conf-yogabook*.deb
```

On Debian, install firmware when required:

```sh
sudo apt install firmware-intel-sound firmware-brcm80211
```

Reboot and verify the running kernel:

```sh
uname -r
```

The output should contain `yogabook`.

## Per-distribution installers

Clone this repository once, then run the installer for the target operating
system. The Ubuntu, Debian, Fedora and Arch scripts download the latest
successful package artifact from `LamPPKK/YogaBook-Linux` automatically. The
download path uses GitHub's public Actions API and requires `curl`, `jq` and
`unzip`.

Ubuntu 24.04/26.04:

```sh
sudo apt install curl jq unzip
./scripts/install/install-ubuntu.sh
```

Debian Bookworm/Trixie/Forky/Sid:

```sh
sudo apt install curl jq unzip
./scripts/install/install-debian.sh
```

Fedora/RHEL-compatible distributions:

```sh
sudo dnf install curl jq unzip
./scripts/install/install-fedora.sh
```

Arch/Manjaro:

```sh
sudo pacman -S --needed curl jq unzip
./scripts/install/install-arch.sh
```

Alpine uses locally built `.apk` files because this repository does not yet
publish a stable Alpine kernel artifact:

```sh
doas apk add curl
doas ./scripts/install/install-alpine.sh --package-dir ./packages
```

All installers accept `--package-dir DIR` for offline installation. The
generic local installer remains available for mixed package directories:

The repository includes `install-yogabook.sh` for a local package directory:

```sh
sudo ./install-yogabook.sh --package-dir ./packages
```

The generic script detects and installs `.deb`, `.rpm`, `.pkg.tar.*` and `.apk`
artifacts using the available package manager. It defaults to the ANSI `pc104`
touch-keyboard layout. For an ISO keyboard use:

```sh
sudo ./install-yogabook.sh --keyboard-layout pc105
```

Use `--no-keyboard-layout` to preserve the current layout.

## Building the kernel with GitHub Actions

Open **Actions → Build Yoga Book kernel → Run workflow** in your
`LamPPKK/YogaBook-Linux` repository. The workflow builds the selected kernel
tag or branch on Ubuntu 24.04 and Ubuntu 26.04, then publishes the generated
Debian packages and SHA-256 checksums as artifacts.

The default source ref is `v6.18.x-yogabook`. A tag push matching
`kernel-*` also starts a build automatically.

Kernel workflows apply the v5 Yoga Book camera series before building. It adds
OV2740 front-camera, OV8858 rear-camera, AtomISP/CSI-2 bridge and WV517S focus
support. The series was runtime-tested on YB1-X91L; the build artifact alone
does not replace testing on the target tablet.

The **Build latest Yoga Book userspace packages** workflow calls the local
`scripts/build/build-userspace-deb.sh` helper and builds fresh Debian packages
from the LamPPKK source mirrors for the touch keyboard, ALSA UCM configuration
and Yoga Book support service. Each artifact includes the exact source commit
and SHA-256 checksums.

The **Build native Yoga Book packages** workflow calls the local kernel build
helpers and additionally provides:

- Fedora RPM packages using `binrpm-pkg`
- Arch Linux kernel and modules artifacts

These jobs build the same Yoga Book kernel configuration; they do not convert
Debian packages into RPM or Arch packages.

### ChromiumOS

The native-package workflow also builds a generic x86_64 Yoga Book kernel and
modules archive that can be used as an input to a ChromiumOS board build.
ChromiumOS images are board-specific: a bootable image still requires the
exact board name, ChromiumOS release branch, firmware and image layout. The
kernel artifact is not itself a complete ChromiumOS image.

## Installing Linux on the tablet

1. Write a supported Linux ISO to a USB drive.
2. Connect a powered microUSB OTG hub, USB drive and physical keyboard.
3. Disable Secure Boot and boot from USB using the Volume Up key.
4. Install Linux normally; GNOME is recommended for automatic rotation.
5. Install the Yoga Book packages and reboot.

A physical keyboard may be needed during installation because the sensor keyboard
driver is userspace software and is not available until after the system is
installed.

## Troubleshooting

Check the open issue tracker before reporting a duplicate:
<https://github.com/LamPPKK/YogaBook-Linux/issues>.

Useful diagnostics:

```sh
uname -a
sudo dmesg -T > dmesg.txt
systemctl --failed
```

Include the exact device model (`YB1-X90F`, `YB1-X90L`, `YB1-X91F` or
`YB1-X91L`), distribution version and the relevant logs.
