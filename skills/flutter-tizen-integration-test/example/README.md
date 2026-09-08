# Example: Integration test on a Tizen target

A device test that drives a TV remote flow, plus the bounded runner used to execute it unattended.

## Files

- `app_test.dart` — `integration_test/` entrypoint: initializes `IntegrationTestWidgetsFlutterBinding`, walks a grid with D-pad keys, asserts focus and navigation, and verifies that refresh loads expected data. Shows the `ValueKey` + `sendKeyEvent` pattern rather than text matching or `sdb` key injection.
- `integration_test_runner.sh` — verifies the target with `sdb devices`, runs `flutter-tizen test` under `timeout`, captures the console (the only log channel that works on TV), and greps the captured log for the failure patterns that matter.

## Scenario

CI needs one command that either passes or fails with a readable reason on the TV 9.0 emulator. The runner never touches `sdb dlog` (locked down on TV, silently empty) and never leaves a `flutter-tizen run` session behind.

## Adapting the refresh test

Declare the operation's required privileges in `tizen/tizen-manifest.xml`, grant any required runtime permissions, and rebuild/reinstall. Reset the app's stored data and prepare a deterministic backend/device response containing a new item that appears only after refresh. Replace `loaded_item_123` with the key on the widget displaying that item's actual returned data, not a marker set merely when the refresh button is pressed.

The test asserts that the item is initially absent, waits up to 10 seconds for it after refresh, and checks that no error banner appears. Adjust the wait budget to the operation's expected latency. Catching and silently ignoring a privilege error must leave the item absent and fail the test. To test permission denial separately, prepare a denied-permission condition and assert the expected error code or error UI.
