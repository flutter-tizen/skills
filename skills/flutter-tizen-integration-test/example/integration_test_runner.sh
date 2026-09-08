#!/usr/bin/env bash
# Run a Flutter-Tizen integration test unattended and fail loudly.
# Companion to ../SKILL.md.

set -eu

DEVICE_ID="${DEVICE_ID:-}"
TEST_FILE="${TEST_FILE:-integration_test/app_test.dart}"
LOG_FILE="${LOG_FILE:-integration_test.log}"
RUN_TIMEOUT="${RUN_TIMEOUT:-600}"

# The console of the test command is the only log channel that works on every
# Tizen target: on Samsung TV `sdb capability` reports secure_protocol:enabled,
# so `sdb dlog` and `sdb shell` return nothing *without erroring*. Grepping them
# would silently report a pass.
# A bare `PlatformException` is not a failure marker: a passing test may print
# one while probing a missing privilege with `try` / `on PlatformException`;
# an unhandled one still surfaces as `Unhandled Exception:`.
FAILURE_PATTERNS='Unhandled Exception:|EXCEPTION CAUGHT BY|MissingPluginException|SIGSEGV|SIGABRT|Some tests failed'

# GNU `timeout` is absent on stock macOS; coreutils installs it as `gtimeout`.
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_CMD=timeout
elif command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_CMD=gtimeout
else
  echo "Neither 'timeout' nor 'gtimeout' found; install GNU coreutils" >&2
  exit 2
fi

if [ -z "$DEVICE_ID" ]; then
  # Pick the only attached target, or make the ambiguity explicit.
  # `while read` instead of `mapfile`: macOS ships Bash 3.2, which lacks it.
  ids=()
  while IFS= read -r id; do ids+=("$id"); done \
    < <(sdb devices | awk 'NR>1 && $2=="device" {print $1}')
  if [ "${#ids[@]}" -eq 1 ]; then
    DEVICE_ID="${ids[0]}"
  else
    echo "Set DEVICE_ID: ${#ids[@]} targets in state 'device' (${ids[*]:-none})" >&2
    exit 2
  fi
fi

echo "==> target   : $DEVICE_ID"
echo "==> test     : $TEST_FILE"
echo "==> log      : $LOG_FILE"

# `flutter-tizen test` picks up integration_test/ and wraps the entrypoint with a
# registrant for Dart-only Tizen plugins. Plain `flutter test` skips that and
# every plugin call throws MissingPluginException.
set +e
"$TIMEOUT_CMD" "$RUN_TIMEOUT" flutter-tizen test "$TEST_FILE" -d "$DEVICE_ID" 2>&1 | tee "$LOG_FILE"
status="${PIPESTATUS[0]}"
set -e

if [ "$status" -eq 124 ]; then
  echo "FAIL: timed out after ${RUN_TIMEOUT}s (device may still hold the app)" >&2
  exit 1
fi

# A zero exit with a failure line in the log means the reporter and the process
# disagree; trust the log.
if grep -qiE "$FAILURE_PATTERNS" "$LOG_FILE"; then
  echo "FAIL: failure pattern in $LOG_FILE" >&2
  grep -inE "$FAILURE_PATTERNS" "$LOG_FILE" >&2
  exit 1
fi

if [ "$status" -ne 0 ]; then
  echo "FAIL: flutter-tizen test exited $status" >&2
  exit "$status"
fi

# An empty log is not a pass — it means the test never produced output.
if [ ! -s "$LOG_FILE" ]; then
  echo "FAIL: $LOG_FILE is empty; the test produced no output" >&2
  exit 1
fi

echo "PASS"
