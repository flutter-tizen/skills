# Changelog

## Unreleased

Closes the gaps where [flutter/agent-plugins](https://github.com/flutter/agent-plugins) skills give
Tizen-incorrect guidance.

### Skills

- **flutter-tizen-integration-test** — Run `integration_test` suites on Tizen targets with
  `flutter-tizen test` (the supported path; it registers Dart-only Tizen plugins) or `flutter-tizen
  drive` when a host driver is needed. Replaces the upstream `chromedriver` / `-d chrome` /
  `flutter build apk` / Firebase Test Lab recipes, none of which apply to Tizen.

### Rules

- `rules/flutter_tizen_cli.md` (+ `.mdc` for Cursor) — always-on rule carrying the invariants no
  single skill can enforce: `flutter-tizen` instead of `flutter`, no `logs` / `screenshot` /
  `widget-preview` command, read logs from the `run` console, and attach the Dart MCP server by VM
  Service URI rather than DTD.

### Changed

- **flutter-tizen-device** — documents attaching the Dart MCP server to a running Tizen app through
  the `vm_service` tool's `connect` command, with the tools that then become available.
- **flutter-tizen-use-plugins** — now also triggers on privileges needed by plain Dart code with no
  plugin involved (`package:http` / `dart:io` sockets need the internet privilege).

## 0.1.0

Initial release of the Flutter-Tizen agent skill set.

### Skills

- **flutter-tizen-setup** — Install and verify the flutter-tizen toolchain (Tizen SDK, `sdb`, certificate profile, flutter-tizen CLI).
- **flutter-tizen-build-tpk** — Build, sign, and inspect Tizen TPK packages for the `common` and `tv` device profiles.
- **flutter-tizen-device** — Connect to Tizen devices and emulators over `sdb`, run apps, read logs, and attach a debugger.
- **flutter-tizen-tv-remote-input** — Wire up Samsung TV remote D-pad focus traversal, OK/Back, color, and media keys.
- **flutter-tizen-use-plugins** — Select and configure `*_tizen` plugins, including privilege declarations in `tizen-manifest.xml`.
- **flutter-tizen-create-plugin** — Scaffold a new C++/C# Tizen plugin wired to Dart through a method channel.
- **flutter-tizen-plugin-regression-test** — Run example apps and integration tests for flutter-tizen plugins on the TV emulator and report failures.

### Tooling

- `tool/dart_skills_lint` — SKILL.md linter (vendored from flutter/skills).
- `tool/generator` — SKILL.md generator driven by `resources/flutter_tizen_skills.yaml`.

Licensed under the [BSD 3-Clause License](LICENSE).
