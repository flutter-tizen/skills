---
name: flutter-tizen-setup
description: Install and verify the flutter-tizen toolchain (Tizen SDK, sdb, certificate profile, flutter-tizen CLI). Use when bootstrapping a new development host, when `flutter-tizen doctor` reports missing components, when `sdb` or `tizen` CLI is not found or a certificate profile is missing, or before a clean-room device build.
metadata:
  target: flutter-tizen
  category: environment
  last_modified: Wed, 27 May 2026 08:02:04 GMT
---
# Setting up flutter-tizen

## Prerequisites

Confirm the host environment before installing anything:

- 64-bit Linux (Ubuntu 22.04 / 24.04 verified), macOS x64, or Windows x64.
- `git`, `unzip`, `bash`, Python 3 available on `PATH`.
- For the Tizen emulator on Linux, HW virtualization (Intel VT-x / AMD-V) must be enabled in BIOS. On Ubuntu 24.04, install `libsdl1.2debian` if the emulator fails to launch.
- For TV / RPi targets, the host PC and the device must reach each other on the same L2 network.

## Install the Tizen SDK

Tizen Studio 6.1 was the last supported standalone release; the `VS Code Extension for Tizen` is now the recommended channel for the Tizen SDK.

1. Install the **VS Code Extension for Tizen** (or a legacy Tizen Studio install if already in use).
2. Open `Tizen: Package Manager` from the Command Palette and install:
   - `[Advanced] - [6.0 IOT-Headed + Mobile]` — required by flutter-tizen for the base build.
   - `[Advanced] - [9.0 Tizen or later]` — required only to use Tizen emulators.
   - The TV 9.0 emulator image — required only for TV emulator targets.
3. Add the SDK tools directory to `PATH` so that `sdb` and `tizen` are resolvable from a shell:
   ```sh
   export PATH="$HOME/tizen-studio/tools:$PATH"
   # Or, for the VS Code extension layout:
   export PATH="$HOME/.tizen-extension-platform/server/sdktools/data/tools:$PATH"
   ```
   The extension-layout path can move between extension versions; if `sdb` is not at that path, locate it with `find ~ -name sdb -type f 2>/dev/null` and use its parent directory.

   The `export` lines are for Linux/macOS shells. On Windows, add the SDK `tools` directory and `flutter-tizen\bin` to the user `Path` instead, as documented in the official [windows-install.md](https://github.com/flutter-tizen/flutter-tizen/blob/master/doc/windows-install.md).

   Verify with:
   ```sh
   which sdb && sdb version
   which tizen && tizen version
   ```

## Install flutter-tizen

`flutter-tizen` ships its own pinned Flutter SDK under `flutter-tizen/flutter`. **Do not install upstream `flutter` separately and put it before flutter-tizen on `PATH` — the two SDKs will fight over `.flutter_tool_state`.**

1. Clone the tool:
   ```sh
   git clone https://github.com/flutter-tizen/flutter-tizen.git
   ```
2. Add `flutter-tizen/bin` to `PATH`:
   ```sh
   export PATH="$PWD/flutter-tizen/bin:$PATH"
   ```
3. Trigger the first-run bootstrap (downloads the bundled Flutter SDK and engine artifacts):
   ```sh
   flutter-tizen --version
   ```

## Create a certificate profile

Tizen refuses to install unsigned packages — even on the emulator. Create one Samsung distributor profile per host:

1. Easiest: use **Certificate Manager** in the VS Code extension. Pick `Create Samsung Certificate` when unsure.
2. CLI alternative (after `tizen` is on `PATH`):
   ```sh
   tizen security-profiles add -n my-profile \
       -a /path/to/author.p12 -p author_password \
       -d /path/to/distributor.p12 -dp distributor_password
   tizen security-profiles list
   ```
3. When creating a distributor certificate, register the target device's `DUID`. For an emulator, run it first; the DUID then appears in Certificate Manager's device list automatically.
4. Pass the profile name at build time when the active profile is wrong: `flutter-tizen build tpk --security-profile my-profile`.

## Verify the toolchain

Run, in order:

```sh
flutter-tizen doctor -v
sdb version
sdb devices
flutter-tizen devices
```

What the output must show:

- `flutter-tizen doctor` reports a green check for **Flutter** and **Tizen toolchain**. A green check for `Connected device` only matters if a device is plugged in.
- `sdb devices` lists at least one target as `device` (not `offline` or `unauthorized`) before continuing.
- `flutter-tizen devices` lists the matching Tizen target with a non-empty device ID (e.g. `emulator-26101`).

If `flutter-tizen doctor` says `To install missing package(s)`, install the listed package from Package Manager and re-run; the missing-package check is the most common false-`doctor` for new hosts.

## Workflow: First-Time Setup

Copy this checklist and tick items as completed:

### Task Progress
- [ ] **Step 1: Verify host prerequisites.** OS, `git`, `unzip`, Python 3 present; virtualization enabled if emulator targets are needed.
- [ ] **Step 2: Install Tizen SDK** via VS Code Extension for Tizen, with `6.0 IOT-Headed + Mobile` (and optionally `9.0` + TV 9.0 image).
- [ ] **Step 3: Put `sdb` and `tizen` on `PATH`** and confirm with `sdb version` and `tizen version`.
- [ ] **Step 4: Clone flutter-tizen** and put `bin/` on `PATH`; run `flutter-tizen --version` to bootstrap.
- [ ] **Step 5: Create a Samsung certificate profile** via Certificate Manager (or `tizen security-profiles add`).
- [ ] **Step 6: Plug in a device or launch an emulator**, then check `sdb devices` shows it as `device`.
- [ ] **Step 7: Run `flutter-tizen doctor -v`** and resolve every red item before continuing to any build skill.
- [ ] **Step 8: Smoke build.** `flutter-tizen create demo && cd demo && flutter-tizen build tpk --debug --device-profile common` must succeed end-to-end.

## Troubleshooting

| Symptom | Likely cause | Action |
|---|---|---|
| `flutter-tizen doctor` says `Tizen toolchain ✗ To install missing package(s)` | Required SDK package not installed | Open Tizen Package Manager and install the package(s) listed by `doctor -v` |
| `sdb devices` shows `unauthorized` | Device hasn't accepted the host RSA key | Confirm the developer-mode prompt on the device |
| Certificate Manager refuses to create a distributor cert | Device DUID not registered | Connect the device first so its DUID is auto-populated |
| `flutter-tizen` invokes the wrong Flutter SDK | Upstream `flutter` is earlier on `PATH` | Put `flutter-tizen/bin` ahead of any other Flutter on `PATH`, or use absolute paths |
| Emulator fails to start on Ubuntu 24.04 | Missing legacy SDL runtime | `sudo apt install libsdl1.2debian` |
| `Currently on an unknown channel` warning from `doctor` | flutter-tizen's bundled Flutter uses a `user-branch` channel | Expected — this warning can be ignored for flutter-tizen |
