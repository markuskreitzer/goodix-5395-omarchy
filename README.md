# Goodix 27c6:5395 on Omarchy

This repository packages the experimental Linux driver for the Goodix HTK32 fingerprint reader with USB ID `27c6:5395`. This reader is present in the Dell XPS 15 7590, XPS 15 9570, Precision 5540, and related systems.

The package replaces Arch Linux's stock `libfprint` with a build that includes the [`goodix53x5`](https://github.com/AndyHazz/goodix53x5-libfprint) driver. It supports `27c6:5335`, `27c6:5385`, and `27c6:5395`.

## Validated configuration

The following configuration completed enrollment and returned `verify-match` on 2026-08-12:

| Component | Value |
| --- | --- |
| Computer | Dell XPS 15 7590 |
| BIOS | 1.38.0 |
| Operating system | Omarchy on Arch Linux |
| Kernel | 7.1.3-arch1-2 |
| Reader | Goodix HTK32, `27c6:5395` |
| Driver | `goodix53x5` at commit `309d4c6999a1cdce172c1ca1ee81387b5078d38f` |
| libfprint | 1.94.10 |
| fprintd | 1.94.5 |

The driver unit tests for GTLS/GEA crypto, SIGFM extraction, and SIGFM matching also pass with OpenCV 5.0.0.

## Install

Confirm the device ID:

```bash
lsusb -d 27c6:5395
```

Clone and install the package:

```bash
git clone https://github.com/markuskreitzer/goodix-5395-omarchy.git
cd goodix-5395-omarchy
./scripts/install-driver.sh
```

The package manager asks whether it can remove stock `libfprint`. Answer `y`. The replacement package provides the same shared library interface for `fprintd`.

Confirm that `fprintd` sees the reader:

```bash
fprintd-list "$USER"
```

The expected device name is `Goodix HTK32 Fingerprint Sensor`.

## Enroll and verify

Enroll the right index finger:

```bash
fprintd-enroll -f right-index-finger "$USER"
```

Use the center of the finger pad. Press flat and cover the full sensor. Move the finger a small distance between captures.

Verify the enrolled print:

```bash
fprintd-verify -f right-index-finger "$USER"
```

The expected result is:

```text
Verify result: verify-match (done)
```

This small sensor is sensitive to position and pressure. Retry once before you re-enroll. If failures continue, delete the print and enroll it again:

```bash
fprintd-delete "$USER"
fprintd-enroll -f right-index-finger "$USER"
```

## Enable Omarchy authentication

Do not run `omarchy setup security fingerprint` after this package is installed. That command installs `libfprint-git`, which conflicts with `libfprint-goodix53x5`.

Use the included helper instead:

```bash
./scripts/configure-omarchy-auth.sh
```

The helper:

- adds `pam_fprintd.so` to `sudo` and Polkit;
- enables fingerprint input in Hyprlock when the setting already exists;
- keeps one backup of each changed configuration file.

Test `sudo` in a new terminal before you close the current session:

```bash
sudo -k
sudo -v
```

Touch the reader when `sudo` asks for the enrolled finger. The password path remains available after a failed scan or timeout.

## Update

Pull this repository and rerun the installer:

```bash
git pull --ff-only
./scripts/install-driver.sh
```

Rebuild this package when Arch updates `libfprint` to a new ABI or when the driver commit changes.

## Roll back

Restore stock `libfprint`:

```bash
sudo pacman -S libfprint
sudo systemctl restart fprintd.service
```

Remove fingerprint authentication from Omarchy:

```bash
omarchy remove security fingerprint
```

The Omarchy removal command also removes `fprintd`. Use only the first rollback sequence if you want to keep `fprintd` with stock readers.

## Troubleshooting

### No devices available

Confirm all three layers:

```bash
lsusb -d 27c6:5395
pacman -Q libfprint-goodix53x5 fprintd
systemctl status fprintd.service --no-pager
```

Then restart the service:

```bash
sudo systemctl restart fprintd.service
fprintd-list "$USER"
```

### USB resource is busy

Inspect the interface owner:

```bash
lsusb -t
```

Recent driver revisions detach `cdc_acm` when they claim the reader. An old `/etc/udev/rules.d/91-goodix-fingerprint.rules` workaround is not required.

### GTLS identity verification fails

Retry once. The first open can finish the sensor pairing and the second open can succeed.

If Windows Hello has paired the reader, Linux and Windows can replace each other's sensor key. Re-enrollment can be required after switching operating systems.

### Build cannot find glib-mkenums

Install `glib2-devel`:

```bash
omarchy pkg add glib2-devel
```

This repository includes `glib2-devel` in `makedepends` because Arch separates the GLib build tools from `glib2`.

## Security notes

This is an experimental, convenience-grade driver for a small 108 by 88 pixel sensor. Keep password authentication enabled.

The driver uses an all-zero GTLS pre-shared key. A device that can impersonate the sensor can derive the same session keys. Fingerprint templates use serialized SIGFM features rather than raw images, but they remain biometric data and must be protected.

## Sources and credit

- [`AndyHazz/goodix53x5-libfprint`](https://github.com/AndyHazz/goodix53x5-libfprint): current libfprint driver and SIGFM integration
- [`goodix-fp-linux-dev`](https://github.com/goodix-fp-linux-dev): protocol reverse engineering, firmware research, and SIGFM
- [`libfprint-goodix53x5` on AUR](https://aur.archlinux.org/packages/libfprint-goodix53x5): Arch packaging maintained by AndyHazz
- [`libfprint` supported devices](https://fprint.freedesktop.org/supported-devices.html): mainline support status

The fetched driver and libfprint sources use LGPL-2.1-or-later. The helper scripts and documentation in this repository use the MIT License.
