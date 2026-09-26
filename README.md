# Yoga Book Linux

Linux support for Lenovo Yoga Book tablets:

- YB1-X90F/L — Android models
- YB1-X91F/L — Windows models

The project contains the Yoga Book kernel, touch keyboard support, audio
configuration, sensor support and distribution packaging information.

## Current status

The default kernel is based on the `v6.18.x-yogabook` branch. Most hardware
support is available through the upstream Linux kernel and Yoga Book patches.

Known limitations include:

- Cameras are not supported.
- LTE may not work on L variants.
- Audio still requires the Yoga Book-specific configuration.
- Suspend, charging while powered on, screen brightness, stylus axes and
  microphone channel mapping may vary by device firmware and desktop environment.

Please include the device model and `dmesg`/`journalctl` output when reporting
an issue: <https://github.com/jekhor/yogabook-linux/issues>.

## Installation

The easiest approach is to install a distribution supported by the package
repositories, then install these packages:

- `linux-image-yogabook`
- `linux-headers-yogabook` (optional)
- `touch-keyboard`
- `yogabook-support`
- `alsa-ucm-conf-yogabook`

Available package targets currently include Ubuntu 24.04, Ubuntu 25.10,
Ubuntu 26.04, Debian Trixie/Forky/Testing/Sid, Arch Linux and Alpine Linux.

Package repositories and build scripts:

- Debian/Ubuntu: <https://gitlab.imanuel.dev/packages/yogabook/building/apt-build>
- Arch Linux: <https://gitlab.imanuel.dev/packages/yogabook/building/pacman-build>
- Alpine Linux: <https://gitlab.imanuel.dev/packages/yogabook/building/apk-build>
- Package index: <https://packages.ulbricht.casa/linux-yogabook/-/packages>

For Debian or Ubuntu, install downloaded packages with:

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

## Installer script

The repository includes `install-yogabook.sh` for a local package directory:

```sh
sudo ./install-yogabook.sh --package-dir ./packages
```

The script detects and installs `.deb`, `.rpm`, `.pkg.tar.*` and `.apk`
artifacts using the available package manager. It defaults to the ANSI `pc104`
touch-keyboard layout. For an ISO keyboard use:

```sh
sudo ./install-yogabook.sh --keyboard-layout pc105
```

Use `--no-keyboard-layout` to preserve the current layout.

## Building the kernel with GitHub Actions

Open **Actions → Build Yoga Book kernel → Run workflow** in your fork. The
workflow builds the selected kernel tag or branch on Ubuntu 24.04 and publishes
the generated Debian packages and SHA-256 checksums as an artifact.

The default source ref is `v6.18.x-yogabook`. A tag push matching
`kernel-*` also starts a build automatically.

Kernel workflows apply the v5 Yoga Book camera series before building. It adds
OV2740 front-camera, OV8858 rear-camera, AtomISP/CSI-2 bridge and WV517S focus
support. The series was runtime-tested on YB1-X91L; the build artifact alone
does not replace testing on the target tablet.

The **Build latest Yoga Book userspace packages** workflow builds fresh Debian
packages from the current upstream branches for the touch keyboard, ALSA UCM
configuration and Yoga Book support service. Each artifact includes the exact
source commit and SHA-256 checksums.

The **Build native Yoga Book packages** workflow additionally provides:

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
<https://github.com/jekhor/yogabook-linux/issues>.

Useful diagnostics:

```sh
uname -a
sudo dmesg -T > dmesg.txt
systemctl --failed
```

Include the exact device model (`YB1-X90F`, `YB1-X90L`, `YB1-X91F` or
`YB1-X91L`), distribution version and the relevant logs.
