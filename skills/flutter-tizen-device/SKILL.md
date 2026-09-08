---
name: flutter-tizen-device
description: Connect to and run Flutter apps on Tizen devices and emulators using `sdb` and `flutter-tizen run`. Use when bringing up a TV / RPi / emulator target, when `sdb devices` shows offline or unauthorized, when reading app logs, or when attaching a debugger to a running app.
metadata:
  target: flutter-tizen
  category: device
  last_modified: Wed, 27 May 2026 08:02:04 GMT
---
# Connecting, running, and logging Tizen targets

## Concepts

`sdb` (Samsung Debug Bridge) is Tizen's equivalent of `adb`. `flutter-tizen` talks to devices exclusively through `sdb`, so anything that breaks `sdb devices` breaks every flutter-tizen command. A few rules:

- A USB-connected device uses an `sdb` daemon over USB.
- A network-connected TV / RPi / emulator uses `sdb connect <ip>:<port>` (default port `26101`).
- Every flutter-tizen invocation that touches a device accepts `-d <device-id>`. If multiple devices are connected and `-d` is omitted, the command will error.

## Connecting a device

### Emulator

A running Tizen emulator is auto-registered as `emulator-26101` (or `26103`, `26105`, … for additional instances).

```sh
flutter-tizen emulators                          # list available emulator images
flutter-tizen emulators --launch <emulator-id>   # start one
sdb devices                                      # verify it shows up
```

### Real TV (Samsung)

1. Enable Developer Mode on the TV (Apps → App Settings → enter `12345`, enable Developer Mode, set the host PC IP).
2. From the host:
   ```sh
   sdb connect <tv-ip>          # uses port 26101 by default
   sdb devices                  # should list <tv-ip>:26101 as device
   ```
3. Power-cycling the TV usually drops the connection; reconnect with `sdb connect` each session.

### Raspberry Pi (Tizen)

After flashing Tizen to the SD card and booting, configure sdbd on the device, then `sdb connect <rpi-ip>` from the host.

## Selecting the active device

```sh
flutter-tizen devices                      # list all reachable Flutter devices
flutter-tizen -d emulator-26101 run        # explicit selection
flutter-tizen -d <substring> run           # prefix match also works
```

When scripting, prefer full device IDs over prefixes — prefix matching is ambiguous when two emulators are running.

## Running an app

```sh
# Default: debug mode, hot reload enabled, foreground attach
flutter-tizen -d <id> run

# Performance mode (AOT, instrumentation on)
flutter-tizen -d <id> run --profile

# Delay app execution until a debugger attaches
flutter-tizen -d <id> run --start-paused
```

While the app runs, keypresses in the terminal are forwarded:

- `r` — hot reload
- `R` — hot restart
- `h` — list **all** interactive commands (the full set below is hidden until you press `h`)
- `d` — detach (leave the app running, stop `flutter-tizen run`)
- `c` — clear the screen
- `q` — quit and detach

The default key menu printed by `flutter-tizen run` is exactly `r R h d c q` (verified). Less-common keys such as `p` (toggle `debugPaintSizeEnabled`) and `o` (toggle platform) are only listed after pressing `h`.

`flutter-tizen run` is the only flutter-tizen command that builds *and* installs *and* launches; for already-installed apps see [Attaching a debugger](#attaching-a-debugger).

## Reading app logs

> **Tizen TV targets ship a locked-down `sdb`** — verified on `T-samsung-10.0-x86_64`: `sdb capability` shows `secure_protocol:enabled` + `intershell_support:disabled`, so log/shell access over `sdb` is unavailable (silently, with no error). Read app output from the **foreground `flutter-tizen run` session** instead.

`flutter-tizen run` streams Dart `print`/`debugPrint` and Flutter engine messages in the terminal it runs in:

```sh
flutter-tizen -d <id> run                    # logs stream live in this terminal
flutter-tizen -d <id> run 2>&1 | tee app.log # also capture to a file
```

The same session prints the Dart VM Service URL (for DevTools) and accepts the hot-reload keys below.

## Attaching a debugger

`flutter-tizen run` builds, installs, launches, **and** attaches the Dart VM service in one step — prefer it. It streams logs and prints the VM Service URL in the foreground.

For an app that is already running on the device, attach with its VM Service URL:

```sh
flutter-tizen -d <id> attach --debug-url http://127.0.0.1:<port>/<token>=/
```

The trailing `=/` is part of the URL — keep it. The URL comes from the app's own `flutter-tizen run` session, so launch the app with `flutter-tizen run` (which prints it directly) rather than from its icon.

For VS Code, the bundled `flutter-tizen: Attach (project)` configuration automates this.

## Driving the app from the Dart MCP server

The Dart MCP server (`dart mcp-server`) cannot launch a Tizen app — it has no Tizen device backend, and its DTD discovery (`dtd` → `listDtdUris`) generally does not surface one. Attach by **VM Service URI** instead:

1. `flutter-tizen -d <id> run` and copy the printed `http://127.0.0.1:<port>/<token>=/` URL (the trailing `=/` is part of it).
2. Call the `vm_service` tool with `command: connect` and that URL as `appUri`. This is the documented path for "apps not launched via DTD".
3. Once connected, the app-level tools work as they do on any other platform:

| Tool | Use |
|---|---|
| `hot_reload` / `hot_restart` | Push an edit without leaving the terminal |
| `get_runtime_errors` | Last exceptions, including ones that scrolled past in the console |
| `widget_inspector` (`get_widget_tree`) | See what is actually mounted before guessing at finders |
| `flutter_driver_command` | Tap / scroll / enter text against real widgets |

Use the Dart SDK that ships with flutter-tizen (`flutter-tizen`'s bundled `flutter/bin/dart`) so the MCP server matches the app's engine.

## Workflow: Bring Up a Target and Read Logs

### Task Progress
- [ ] **Step 1: Confirm connectivity.** `sdb devices` shows the target as `device` (not `offline`).
- [ ] **Step 2: Select the device.** Capture the exact `device-id` and use it as `-d <id>` for every subsequent command.
- [ ] **Step 3: Build + run.** `flutter-tizen -d <id> run` (or `--profile` / `--release`). Logs stream in this terminal.
- [ ] **Step 4: Reproduce the issue / exercise the feature.** Watch the `run` console; use `r` for hot reload as needed. To keep a copy, re-run with `2>&1 | tee app.log`.
- [ ] **Step 5: If debugging an externally-launched app**, attach with `flutter-tizen -d <id> attach --debug-url <url>` (start it via `flutter-tizen run` so the URL is printed).
- [ ] **Step 6: Detach cleanly** with `q` or `Ctrl-C`.

## Common failures

| Symptom | Cause | Fix |
|---|---|---|
| `sdb devices` shows `offline` | Device daemon dropped the host RSA fingerprint | `sdb kill-server && sdb start-server && sdb connect <ip>` |
| `No connected Tizen devices` from `flutter-tizen` | sdb sees the device but flutter-tizen does not | Check `sdb -s <id> capability` succeeds; if it hangs, restart the device |
| `flutter-tizen run` hangs at `Installing TPK` | Stale install of the same package conflicts | `sdb -s <id> uninstall <appid>` then retry |
| `flutter-tizen run` console shows no app output | App logged nothing yet, or crashed at startup | Trigger a `debugPrint`; for startup crashes re-run with `--start-paused` |
| `attach --debug-url` fails with `Connection refused` | The app crashed before printing the VM service URL, or printed an `http://...:0/` URL (port not yet allocated) | Restart the app with `flutter-tizen run --start-paused` and use the URL it prints |
| Multiple emulators selected ambiguously | Prefix match collision | Pass the full ID (`emulator-26101`, not `emulator`) |
