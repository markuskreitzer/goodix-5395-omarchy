# Dell XPS 15 fingerprint reader on Linux: Goodix 27c6:5395

Enable the **Dell XPS 15 7590 fingerprint reader on Linux** with the experimental Goodix HTK32 `27c6:5395` driver. This repository provides an Arch Linux package and Omarchy setup helpers for `libfprint`, `fprintd`, `sudo`, Polkit, and Hyprlock.

This setup was tested on a Dell XPS 15 7590 running Omarchy and Arch Linux. Enrollment completed, and `fprintd-verify` returned `verify-match`.

> Read the full story: [I finally got the Dell XPS 15 7590 fingerprint reader working on Linux](https://kreitzer.dev/blog/dell-xps-15-7590-goodix-fingerprint-linux)

## Supported hardware

Run this command before you install anything:

```bash
lsusb | grep -E '27c6:(5335|5385|5395)'
```

The tested device appears as a Goodix or HTMicroelectronics fingerprint reader with USB ID `27c6:5395`.

| Laptop | USB ID | Status |
| --- | --- | --- |
| Dell XPS 15 7590 | `27c6:5395` | Tested with this repository |
| Dell XPS 15 9570 | `27c6:5395` | Listed by the upstream driver |
| Dell XPS 13 9305 | `27c6:5335` | Listed by the upstream driver |
| Dell XPS 13 7390 | `27c6:5385` | Listed by the upstream driver |

The USB ID is more important than the laptop model. Other laptops can work if they contain the same Goodix HTK32 sensor. Do not use this package for a different Goodix USB ID.

## What this repository provides

The fingerprint driver comes from [`AndyHazz/goodix53x5-libfprint`](https://github.com/AndyHazz/goodix53x5-libfprint). This repository adds the parts needed for a repeatable Omarchy and Arch Linux installation:

- an Arch `PKGBUILD` pinned to the driver revision tested on the Dell XPS 15 7590;
- the missing `glib2-devel` build dependency for current Arch systems;
- an installer that builds the package, replaces stock `libfprint`, restarts `fprintd`, and confirms device discovery;
- an Omarchy helper for `sudo`, Polkit, and Hyprlock fingerprint authentication;
- enrollment, verification, rollback, security, and troubleshooting instructions.

No prebuilt driver binary is stored in this repository. The installer builds `libfprint` and the Goodix driver from source on your computer.

## Tested configuration

This configuration completed enrollment and returned `verify-match` on August 12, 2026:

| Component | Tested value |
| --- | --- |
| Computer | Dell XPS 15 7590 |
| BIOS | 1.38.0 |
| Operating system | Omarchy on Arch Linux |
| Kernel | 7.1.3-arch1-2 |
| Reader | Goodix HTK32, `27c6:5395` |
| Driver commit | `309d4c6999a1cdce172c1ca1ee81387b5078d38f` |
| libfprint | 1.94.10 |
| fprintd | 1.94.5 |

The upstream commits after the tested driver commit only update its README and known-device list. The driver source is unchanged as of October 3, 2026.

The GTLS/GEA crypto, SIGFM extraction, and SIGFM matching unit tests passed with OpenCV 5.0.0.

## Quick install for Omarchy and Arch Linux

### 1. Confirm the reader

```bash
lsusb -d 27c6:5395
```

Stop if this command returns no device. Check the USB ID with `lsusb` before you continue.

### 2. Clone the repository

```bash
git clone https://github.com/markuskreitzer/goodix-5395-omarchy.git
cd goodix-5395-omarchy
```

### 3. Build and install the driver

```bash
./scripts/install-driver.sh
```

The script uses `makepkg` and asks Pacman to replace stock `libfprint` with `libfprint-goodix53x5`. Answer `y` when Pacman asks whether it can remove the conflicting package.

The build can take several minutes. It compiles libfprint, the Goodix driver, and the SIGFM matching code locally.

### 4. Confirm device discovery

```bash
fprintd-list "$USER"
```

Expected device name:

```text
Goodix HTK32 Fingerprint Sensor
```

### 5. Enroll a finger

```bash
fprintd-enroll -f right-index-finger "$USER"
```

Use the center of the finger pad. Press it flat and cover the full sensor. Move the finger a small distance between captures.

### 6. Verify the fingerprint

```bash
fprintd-verify -f right-index-finger "$USER"
```

Expected result:

```text
Verify result: verify-match (done)
```

This small sensor is sensitive to finger position and pressure. Try a second time before you delete the enrollment. If matching continues to fail, enroll the finger again:

```bash
fprintd-delete "$USER"
fprintd-enroll -f right-index-finger "$USER"
```

### 7. Enable fingerprint authentication in Omarchy

Do not run `omarchy setup security fingerprint` after you install this package. That command installs `libfprint-git`, which conflicts with `libfprint-goodix53x5`.

Use the included helper:

```bash
./scripts/configure-omarchy-auth.sh
```

The helper performs these actions:

- adds `pam_fprintd.so` to `sudo` and Polkit;
- enables `fingerprint:enabled` in Hyprlock when that setting exists;
- creates one backup of each changed configuration file.

Test `sudo` in a new terminal before you close your current session:

```bash
sudo -k
sudo -v
```

Touch the reader when `sudo` asks for the enrolled finger. Password authentication remains available after a failed scan or timeout.

## Manual package build

The install script is a small wrapper around these commands:

```bash
makepkg --syncdeps --needed --cleanbuild
sudo pacman -U --confirm ./libfprint-goodix53x5-1.94.10-10.1-x86_64.pkg.tar.zst
sudo systemctl restart fprintd.service
```

Use `makepkg --packagelist` to get the exact package path if the package name changes.

## How the driver works

The Goodix HTK32 sends encrypted 108 by 88 pixel fingerprint images through a GTLS-like protocol. The upstream driver initializes and calibrates the sensor, captures a no-finger reference, decrypts each live image, and removes the sensor background. It then uses SIGFM and OpenCV SIFT features to create and compare fingerprint templates.

The package replaces Arch Linux's stock `libfprint` with a compatible build that includes this driver. `fprintd` continues to provide enrollment and verification through the standard Linux fingerprint D-Bus interface.

## Update

Pull this repository and run the installer again:

```bash
git pull --ff-only
./scripts/install-driver.sh
```

Rebuild the package when Arch updates `libfprint` to a new ABI or when this repository changes its driver commit.

The fingerprint template format can change between driver revisions. If verification stops after an update, delete the stored print and enroll it again.

## Roll back to stock libfprint

Restore the Arch Linux package:

```bash
sudo pacman -S libfprint
sudo systemctl restart fprintd.service
```

Remove fingerprint authentication from Omarchy only if you no longer need it:

```bash
omarchy remove security fingerprint
```

The Omarchy removal command also removes `fprintd`. Use only the first rollback sequence if you want to keep `fprintd` for a different supported reader.

## Troubleshooting

### fprintd reports no devices available

Check the hardware, packages, and service:

```bash
lsusb -d 27c6:5395
pacman -Q libfprint-goodix53x5 fprintd
systemctl status fprintd.service --no-pager
```

Restart `fprintd`, then check again:

```bash
sudo systemctl restart fprintd.service
fprintd-list "$USER"
```

### fprintd reports that the device is already claimed

Close any active `fprintd-enroll`, `fprintd-verify`, `sudo`, or Polkit prompt. Wait for `fprintd` to stop after its idle period, or restart it:

```bash
sudo systemctl restart fprintd.service
```

Only one client can claim the fingerprint reader at a time.

### The USB resource is busy

Inspect the interface owner:

```bash
lsusb -t
```

The tested driver revision detaches `cdc_acm` when it claims the reader. You do not need the old `/etc/udev/rules.d/91-goodix-fingerprint.rules` workaround.

### GTLS identity verification fails

Try the command once more. The first open can finish sensor pairing, and the second open can succeed.

Windows Hello and Linux can replace each other's sensor key on dual-boot systems. You can need to enroll the fingerprint again after you switch operating systems.

### The build cannot find glib-mkenums

Install `glib2-devel`:

```bash
omarchy pkg add glib2-devel
```

This repository includes `glib2-devel` in `makedepends` because Arch separates the GLib build tools from `glib2`.

### Verification returns verify-no-match

Place the center of your finger flat on the sensor. Do not use the fingertip or edge. A small change in position can cause a failed match because the sensor image is only 108 by 88 pixels.

If placement changes do not help, delete the print and enroll it again with better coverage.

## Security notes

This driver provides convenience-grade authentication. Keep password authentication enabled.

- The sensor is small and uses SIFT-based matching.
- The driver uses an all-zero GTLS pre-shared key. A device that impersonates the sensor can derive the same session keys.
- Stored templates contain serialized SIGFM features rather than raw images, but they are still biometric data.
- A fingerprint is not a secret that you can replace after exposure. Do not use it as the only protection for sensitive data.

## Development and attribution

This repository was created during a live hardware and Linux integration session with OpenAI Codex. Codex helped identify the USB device, find and assess the upstream driver, adapt the Arch package, diagnose the missing build dependency, run the driver tests, install the package, configure Omarchy authentication, troubleshoot stale `fprintd` claims, and turn the validated process into reusable scripts and documentation.

Codex did not create the underlying Goodix driver or reverse engineer the protocol. That work belongs to the upstream projects and contributors below.

## Sources and credit

- [`AndyHazz/goodix53x5-libfprint`](https://github.com/AndyHazz/goodix53x5-libfprint): current libfprint driver, device integration, and SIGFM path
- [`goodix-fp-linux-dev`](https://github.com/goodix-fp-linux-dev): protocol reverse engineering, firmware research, and SIGFM
- [`libfprint-goodix53x5` on AUR](https://aur.archlinux.org/packages/libfprint-goodix53x5): Arch package maintained by AndyHazz
- [`libfprint` supported devices](https://fprint.freedesktop.org/supported-devices.html): mainline support status
- [OpenAI Codex](https://openai.com/codex/): research, packaging, system integration, testing, troubleshooting, and documentation assistance for this repository

The fetched driver and libfprint sources use LGPL-2.1-or-later. The helper scripts and documentation in this repository use the MIT License.

## Frequently asked questions

### Does the Dell XPS 15 7590 fingerprint reader work on Linux?

Yes, when the laptop contains the Goodix HTK32 reader with USB ID `27c6:5395`. This repository completed enrollment and fingerprint matching on a Dell XPS 15 7590 running Omarchy and Arch Linux.

### Does this work on the Dell XPS 15 9570?

The upstream driver lists the XPS 15 9570 with the same `27c6:5395` reader. This repository has not tested that model directly. Confirm the USB ID before installation.

### Is Goodix 27c6:5395 supported by mainline libfprint?

Not in the stock `libfprint` package used for this test. This project builds a replacement package with the experimental `goodix53x5` driver.

### Can I use this on Ubuntu, Fedora, or another Linux distribution?

The upstream driver supports manual libfprint builds on other distributions. The package and authentication helpers in this repository target Arch Linux and Omarchy.
