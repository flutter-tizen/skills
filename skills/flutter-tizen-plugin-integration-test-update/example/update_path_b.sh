#!/usr/bin/env bash
# Path B: Write regression tests for Tizen-only plugins.
# Example: messageport_tizen — comprehensive integration tests from API inventory.
# Companion to ../SKILL.md.

set -eu

PLUGIN_NAME="messageport"
PLUGIN_DIR="packages/${PLUGIN_NAME}"
DEVICE_ID="${DEVICE_ID:-emulator-26101}"

echo "=== Path B: Updating regression tests for Tizen-only plugin $PLUGIN_NAME ==="

# Step 0: Verify plugin is testable and Tizen-only
echo "1. Checking plugin type..."
if ! grep -qE "^  ${PLUGIN_NAME}: \[[^]]+\]" .github/recipe.yaml; then
    echo "ERROR: ${PLUGIN_NAME} has no testable profile in recipe.yaml"
    exit 1
fi

# Verify it's Tizen-only: match the README package table's first column
# exactly (anchored), not a bare substring — a substring match would also
# hit unrelated rows sharing a name prefix (e.g. "video_player" matching
# "video_player_avplay").
if ! grep -qE "^\| \[\*\*${PLUGIN_NAME}(_tizen)?\*\*\].*\(Tizen-only\)" README.md; then
    echo "ERROR: ${PLUGIN_NAME} is not Tizen-only"
    exit 1
fi
echo "   ✓ ${PLUGIN_NAME} is testable and Tizen-only"

# Step B-1: Inventory the public API
echo ""
echo "2. Inventorying public API..."
echo "   Scanning: ${PLUGIN_DIR}/lib/${PLUGIN_NAME}_tizen.dart"

# Show sample API surface that would be found
echo "   Found public API:"
echo "     - LocalPort.create(portName, {trusted}) → Future<LocalPort>"
echo "     - LocalPort.register(onMessage)"
echo "     - LocalPort.unregister() → Future<void>"
echo "     - LocalPort.registered (bool getter)"
echo "     - RemotePort.connect(remoteAppId, portName, {trusted}) → Future<RemotePort>"
echo "     - RemotePort.send(message) → Future<void>"
echo "     - RemotePort.sendWithLocalPort(message, localPort) → Future<void>"
echo "     - RemotePort.check() → Future<bool>"
echo ""
echo "   Existing test coverage:"
echo "     - LocalPort.create() ✓"
echo "     - RemotePort.connect() ✓"
echo "     - RemotePort.send() ✓"
echo ""
echo "   API surface not yet covered:"
echo "     - LocalPort.register() / unregister() lifecycle"
echo "     - register() throwing when already registered"
echo "     - RemotePort.sendWithLocalPort()"
echo "     - RemotePort.check() for a non-existent port"

# Step B-2: Design regression test cases
echo ""
echo "3. Designing test cases..."
echo "   Categories:"
echo "     - Happy path (5 tests)"
echo "     - Edge cases (3 tests)"
echo "     - Error paths (2 tests)"
echo "     - State transitions (1 test)"
echo "     - Idempotency (2 tests)"
echo "   Total: 13 new test cases"

# Step B-3: Validate (dry-run)
echo ""
echo "4. Validating tests (dry-run)..."
echo "   Command: flutter-tizen drive \\"
echo "     --driver=test_driver/integration_test.dart \\"
echo "     --target=integration_test/${PLUGIN_NAME}_test.dart \\"
echo "     -d $DEVICE_ID"
echo ""
echo "   Expected: All 13 tests pass ✓"

# Step B-4: Commit (dry-run)
echo ""
echo "5. Commit (dry-run)..."
echo "   git add ${PLUGIN_DIR}/example/integration_test/ ${PLUGIN_DIR}/CHANGELOG.md"
echo "   git commit -m \"[${PLUGIN_NAME}] Add regression integration tests\""
echo ""
echo "=== Path B workflow complete ==="
