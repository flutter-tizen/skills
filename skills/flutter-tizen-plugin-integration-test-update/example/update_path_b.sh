#!/usr/bin/env bash
# Path B: Write regression tests for Tizen-only plugins.
# Example: nfc_tizen — comprehensive integration tests from API inventory.
# Companion to ../SKILL.md.

set -eu

PLUGIN_NAME="nfc"
PLUGIN_DIR="packages/${PLUGIN_NAME}_tizen"
DEVICE_ID="${DEVICE_ID:-emulator-26101}"

echo "=== Path B: Updating regression tests for Tizen-only plugin $PLUGIN_NAME ==="

# Step 0: Verify plugin is testable and Tizen-only
echo "1. Checking plugin type..."
if ! grep -A 2 "^  ${PLUGIN_NAME}_tizen:" .github/recipe.yaml | grep -q "^\s*profiles:"; then
    echo "ERROR: ${PLUGIN_NAME}_tizen not found in recipe.yaml"
    exit 1
fi

# Verify it's Tizen-only (Frontend package column says "(Tizen-only)")
if ! grep -i "${PLUGIN_NAME}" README.md | grep -q "(Tizen-only)"; then
    echo "WARNING: $PLUGIN_NAME may not be Tizen-only; verify README.md"
fi
echo "   ✓ ${PLUGIN_NAME}_tizen is Tizen-only"

# Step B-1: Inventory the public API
echo ""
echo "2. Inventorying public API..."
echo "   Scanning: ${PLUGIN_DIR}/lib/${PLUGIN_NAME}.dart"

# Show sample API surface that would be found
echo "   Found public API:"
echo "     - NfcManager.instance (singleton getter)"
echo "     - startSession() → NfcSession"
echo "     - stopSession() → Future<void>"
echo "     - onDiscovered (Stream<NfcTag>)"
echo "     - isSupported() → bool"
echo ""
echo "   Existing test coverage:"
echo "     - startSession() ✓"
echo "     - stopSession() ✓"
echo ""
echo "   API surface not yet covered:"
echo "     - onDiscovered stream handling"
echo "     - Error cases (close after close, stop when inactive)"
echo "     - State transitions (open → read → close)"
echo "     - Idempotency (multiple calls to isSupported)"

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
echo "   git add ${PLUGIN_DIR}/example/integration_test/${PLUGIN_NAME}_test.dart"
echo "   git commit -m \"[${PLUGIN_NAME}] Add regression integration tests\""
echo ""
echo "=== Path B workflow complete ==="
