---
name: flutter-tizen-integration-test
description: Write and run `integration_test` suites on Tizen devices and emulators with `flutter-tizen test` and `flutter-tizen drive`. Use when adding on-device test coverage to a Tizen app, when a widget test is not enough because the flow needs real plugins or real hardware, when choosing between `flutter-tizen test` and `flutter-tizen drive`, or when an integration run has to be unattended on the TV emulator.
metadata:
  target: flutter-tizen
  category: testing
  last_modified: Thu, 27 Aug 2026 00:00:00 GMT
---
# Running integration tests on Tizen

## Scope

This skill is for an **app you are building**. Work inside the `flutter-tizen/plugins` repo — porting or updating a plugin's own integration tests — belongs to the `flutter-tizen-plugin-*` skills instead.

Test *authoring* — the `WidgetTester` API, finders, `pumpAndSettle`, page objects — is platform-agnostic and covered by the general Flutter skill `flutter-add-integration-test`. What changes on Tizen is how the suite is wired up and executed:

| Upstream step | On Tizen |
|---|---|
| `flutter pub add`, `flutter test` | `flutter-tizen pub add`, `flutter-tizen test` — the plain commands leave Tizen platform interfaces unregistered |
| Explore via MCP `launch_app` + `get_widget_tree` | no `launch_app`; start the app with `flutter-tizen run` and attach by VM Service URI |
| `flutter drive` on `-d chrome` / `-d web-server` | `flutter-tizen test integration_test/…`, or `flutter-tizen drive` for a host driver |
| `flutter build apk --debug` + Firebase Test Lab | no equivalent — run on a real device or the TV emulator |

## Concepts

An `integration_test` suite is a `flutter_test` suite that runs **inside the app on the device**, so it sees real plugins, real privileges, and real platform channels. On Tizen that matters more than elsewhere: most `*_tizen` plugins are the only place a feature is implemented, and a host-only widget test mocks exactly the layer that breaks.

Two runners exist, and picking the wrong one is the usual first mistake:

| Runner | Use for | Host driver |
|---|---|---|
| `flutter-tizen test integration_test/<file>_test.dart -d <id>` | Almost everything | none |
| `flutter-tizen drive --driver=… --target=… -d <id>` | Screenshots, timeline/profiling, custom `integrationDriver` response data | `test_driver/integration_test.dart` |

`flutter-tizen test` is the supported default: flutter-tizen detects the `integration_test/` directory and wraps each entrypoint in a generated `main()` that registers Dart-only Tizen plugins before calling yours. Plain `flutter test` skips that wrapper, so Dart-side plugins (`shared_preferences_tizen`, `path_provider_tizen`, …) are unregistered and every call throws `MissingPluginException`.

One suite shape defeats it: if `main()` awaits anything (`await HttpServer.bind(...)`, a config load) **before** declaring its tests, the run dies before the first test with `Bad state: Can't call test() once tests have begun running`, pointing at the first `testWidgets`. The file is not at fault and the same suite runs under `drive` — switch runners instead of restructuring `main()`.

The upstream Flutter recipes for `chromedriver`, `-d chrome`, `-d web-server`, `flutter build apk --debug`, and Firebase Test Lab have no Tizen equivalent. Ignore them.

## Project setup

```sh
flutter-tizen pub add 'dev:integration_test:{"sdk":"flutter"}'
flutter-tizen pub add 'dev:flutter_test:{"sdk":"flutter"}'
flutter-tizen pub get
```

Always `flutter-tizen pub`, never `flutter pub` — the latter does not write the Tizen platform interface into the package config, and the failure only shows up as a runtime `MissingPluginException` inside the test.

Layout:

```
integration_test/
  app_test.dart              # runs on the device
test_driver/
  integration_test.dart      # only needed for `flutter-tizen drive`
```

## Authoring the test

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('signs in and lands on the home grid', (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('email')), 'a@b.c');
    await tester.tap(find.byKey(const ValueKey('sign_in')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home_grid')), findsOneWidget);
  });
}
```

- Target widgets by `ValueKey`, not by visible text — TV builds are localized and text moves.
- `await tester.pumpAndSettle()` after every interaction. If a screen animates forever (a spinner, a looping Rive/Lottie asset), `pumpAndSettle` throws `PumpAndSettleTimedOutException`; pump a fixed duration instead (`await tester.pump(const Duration(milliseconds: 300))`).
- Wrap plugin calls that need a privilege in `try` / `on PlatformException` and `expect` on the error code, so a missing `<privilege>` in `tizen/tizen-manifest.xml` fails the test with a readable reason instead of an unhandled exception.

## Driving the TV remote from a test

D-pad and OK/Back arrive as logical keys, and a test can synthesize them directly:

```dart
await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
await tester.sendKeyEvent(LogicalKeyboardKey.select);   // OK — also send `enter`, firmware varies
await tester.sendKeyEvent(LogicalKeyboardKey.escape);   // Back
await tester.pumpAndSettle();

// Assert focus through the primary focus node, and put the ValueKey on the
// `Focus` / `FocusableActionDetector` itself — that is the element the node
// attaches to. `Focus.of(context)` resolves the nearest *ancestor* scope, so
// calling it on the keyed element's own context reads the wrong node.
expect(
  FocusManager.instance.primaryFocus?.context?.widget.key,
  const ValueKey<String>('tile_2'),
);
```

`sdb shell input_keyevent` does **not** reach the Flutter embedder on any Tizen target — do not build a test harness on it. See flutter-tizen-tv-remote-input for the focus/traversal side.

## Running on a device or emulator

```sh
sdb devices                                   # target must read `device`
flutter-tizen test integration_test/app_test.dart -d <device-id>
```

- `-d <device-id>` is required whenever more than one target is connected; pass the full ID, never a prefix.
- `flutter-tizen test` has **no** `--debug` / `--profile` / `--release` flag — the on-device run is debug, which is also the only mode an emulator can execute (JIT). Build modes exist on `drive`, where `--debug` is the default and `--profile` / `--release` need real hardware.
- `-j` / `--concurrency` is ignored for integration tests, so do not try to shard a device run.
- `--no-uninstall` keeps the app installed after the run (it is removed by default) — useful when the next step is attaching to it. `--ignore-timeouts` avoids a spurious failure when the first build on a cold cache outlasts the test timeout.
- With a host driver:
  ```sh
  flutter-tizen drive \
      --driver=test_driver/integration_test.dart \
      --target=integration_test/app_test.dart \
      -d <device-id> --debug
  ```

## Running unattended

`flutter-tizen test` exits on its own, but a hung test holds the device and blocks the next run. In CI, bound it and treat a timeout as a failure (on macOS GNU `timeout` is not preinstalled — use `gtimeout` from coreutils):

```sh
timeout 600 flutter-tizen test integration_test/app_test.dart -d <id> 2>&1 | tee integration_test.log
status=${PIPESTATUS[0]}    # 124 == timed out
```

Never use a foreground `flutter-tizen run` session as the harness — it stays attached until `q` and will never return.

## Reading failures

The command's own stdout/stderr is the log channel. On Samsung TV targets `sdb dlog` and `sdb shell` return nothing **silently** (`sdb capability` reports `secure_protocol:enabled`), so a grep over them matches an empty stream and reports a false pass.

Scan the captured log case-insensitively for:

```
Unhandled Exception:
EXCEPTION CAUGHT BY
MissingPluginException
SIGSEGV
SIGABRT
Some tests failed
```

A bare `PlatformException` is deliberately absent: a passing test may print one while probing a missing privilege (the `try` / `on PlatformException` advice above); an unhandled one surfaces as `Unhandled Exception:`.

## Inspecting a live app with the Dart MCP server

When a test hangs and the log says nothing, drive the app directly instead of guessing. The Dart MCP server cannot launch a Tizen app, but it can attach to one by VM Service URI:

1. `flutter-tizen -d <id> run` and copy the printed `http://127.0.0.1:<port>/<token>=/` URL (the trailing `=/` is part of it).
2. Call the `vm_service` tool with `command: connect` and that URL as `appUri`. (`dtd` → `listDtdUris` is the DTD-based path and will usually not surface a flutter-tizen app.)
3. Then use `widget_inspector` (`get_widget_tree`) to see what is actually mounted, `get_runtime_errors` for the last exceptions, `flutter_driver_command` to tap/scroll, and `hot_reload` after an edit.

Whatever the inspector shows should become a `ValueKey` assertion in the test.

## Workflow: Add and Run an Integration Test

### Task Progress
- [ ] **Step 1: Add dependencies.** `flutter-tizen pub add 'dev:integration_test:{"sdk":"flutter"}'` + `'dev:flutter_test:{"sdk":"flutter"}'`, then `flutter-tizen pub get`.
- [ ] **Step 2: Pick the runner.** `flutter-tizen test` unless screenshots / profiling / custom driver data are needed; only then add `test_driver/integration_test.dart` and use `flutter-tizen drive`.
- [ ] **Step 3: Add `ValueKey`s** to the widgets the flow touches.
- [ ] **Step 4: Write `integration_test/<name>_test.dart`** starting with `IntegrationTestWidgetsFlutterBinding.ensureInitialized();`.
- [ ] **Step 5: Confirm the target.** `sdb devices` shows `device`; capture the exact device ID.
- [ ] **Step 6: Run.** `timeout 600 flutter-tizen test integration_test/<name>_test.dart -d <id> 2>&1 | tee integration_test.log`.
- [ ] **Step 7: Feedback loop.** Scan the log for the failure patterns above → fix → re-run until green. If the run hangs, attach with `vm_service` + `widget_inspector` and turn the finding into an assertion.
- [ ] **Step 8: Rebuild after any manifest change.** Privileges and other manifest entries do not hot-reload.

## Common failures

| Symptom | Cause | Fix |
|---|---|---|
| `MissingPluginException` for a Dart-only plugin | Ran `flutter test`, or `flutter pub get` instead of `flutter-tizen pub get` | Re-run with `flutter-tizen test` after `flutter-tizen pub get` |
| `Bad state: Can't call test() once tests have begun running`, before any test runs | `main()` awaits something before declaring its tests | Run that suite with `flutter-tizen drive`; do not restructure `main()` |
| `No devices found` / test never starts | No `-d`, or `sdb devices` shows `offline` | `sdb kill-server && sdb start-server && sdb connect <ip>`, then pass the full device ID |
| `PumpAndSettleTimedOutException` | A never-settling animation on screen | Replace `pumpAndSettle()` with fixed `pump(Duration(...))` around that screen |
| Test passes locally, empty log in CI | Log was read from `sdb dlog` on a TV target | Capture the command's own output with `2>&1 \| tee` |
| `PlatformException` with a `permission`/`privilege` code | Privilege missing from `tizen/tizen-manifest.xml` | Add the `<privilege>`, rebuild, reinstall (see flutter-tizen-use-plugins) |
| Run hangs forever in CI | Used `flutter-tizen run`, or no timeout | Use `flutter-tizen test` wrapped in `timeout` |
| Focus assertions fail on the emulator but pass on TV | Key sent through `sdb shell input_keyevent` | Synthesize keys with `tester.sendKeyEvent` instead |

## Related skills

- `flutter-add-integration-test` (flutter/agent-plugins) — authoring the suite. Its MCP `launch_app`, chromedriver, and Firebase Test Lab steps do not apply to Tizen.
- flutter-tizen-device — connecting the target, the `run` console, and attaching the Dart MCP server.
- flutter-tizen-tv-remote-input — the focus and key handling the D-pad assertions above depend on.
- flutter-tizen-plugin-regression-test — the same execution machinery applied to the `flutter-tizen/plugins` repo rather than an app.

## Examples

`example/` holds a runnable pair: `app_test.dart` (a device test that exercises a D-pad flow) and `integration_test_runner.sh` (bounded run, log capture, failure grep) suitable for CI.
