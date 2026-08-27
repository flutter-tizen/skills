#!/usr/bin/env bash
# Path A: Update upstream integration tests for Flutter-based Tizen plugins.
# Example: audioplayers_tizen porting tests from upstream audioplayers 4.1.0.
# Companion to ../SKILL.md.

set -eu

PLUGIN_NAME="audioplayers"
PLUGIN_DIR="packages/${PLUGIN_NAME}"
DEVICE_ID="${DEVICE_ID:-emulator-26101}"

echo "=== Path A: Updating upstream tests for $PLUGIN_NAME ==="

# Step 0: Verify plugin is testable (has a non-empty profile list in recipe.yaml)
echo "1. Checking recipe.yaml for testable plugins..."
if ! grep -qE "^  ${PLUGIN_NAME}: \[[^]]+\]" .github/recipe.yaml; then
    echo "ERROR: ${PLUGIN_NAME} has no testable profile in recipe.yaml"
    exit 1
fi
echo "   ✓ ${PLUGIN_NAME} is testable"

# Step A-1: Determine target version
echo ""
echo "2. Determining upstream target version..."
cd "$PLUGIN_DIR/example"
PUBSPEC="pubspec.yaml"

# Find the dependency line (handles both "audioplayers: 4.1.0" and
# "audioplayers: ^4.1.0"). grep -A 100 rather than -A 1 because the target
# package is rarely the line right after "dependencies:".
DEP_LINE=$(grep -A 100 "^dependencies:" "$PUBSPEC" | grep -m 1 "^\s*${PLUGIN_NAME}:")

if [[ "$DEP_LINE" =~ :[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+)[[:space:]]*$ ]]; then
    # Pinned to an exact version (no ^/>=/< operator) — use it directly.
    TARGET_VERSION="${BASH_REMATCH[1]}"
else
    # Expressed as a range (e.g. "^4.1.0") — resolve the version pub actually
    # picked, per SKILL.md A-1, using the flutter-tizen-pinned SDK (not
    # whichever "flutter" happens to be on PATH).
    TARGET_VERSION=$(flutter-tizen pub deps --style=compact 2>/dev/null | \
        grep -oE "${PLUGIN_NAME} [0-9]+\.[0-9]+\.[0-9]+" | head -n 1 | awk '{print $2}')
    [ -n "$TARGET_VERSION" ] || { echo "ERROR: could not resolve ${PLUGIN_NAME} version from pub deps"; exit 1; }
fi

echo "   Target upstream version: $TARGET_VERSION"
cd - > /dev/null

# Step A-2: Show comparison (dry-run)
echo ""
echo "3. Comparing upstream vs Tizen tests (dry-run)..."
echo "   Upstream (${PLUGIN_NAME}-v${TARGET_VERSION}) integration tests:"
echo "     - testWidgets('play audio from asset')"
echo "     - testWidgets('pause audio playback')"
echo "     - testWidgets('resume paused audio')"
echo "     - testWidgets('stop audio playback')"
echo "     - testWidgets('seek to specific position')"
echo "     - testWidgets('get audio duration')"
echo "     - testWidgets('emit state changes through stream')"
echo "     - testWidgets('set volume level')"
echo ""
echo "   Tizen integration tests (current):"
echo "     - testWidgets('play audio from asset')"
echo "     - testWidgets('pause audio playback')"
echo "     - testWidgets('stop audio playback')"
echo "     - testWidgets('get audio duration')"
echo "     - testWidgets('set volume level')"
echo ""
echo "   Missing (to add):"
echo "     ❌ testWidgets('resume paused audio')"
echo "     ❌ testWidgets('seek to specific position')"
echo "     ❌ testWidgets('emit state changes through stream')"

# Step A-3: Add missing tests (dry-run - show what would be added)
echo ""
echo "4. Adding missing test cases..."
echo "   Would add 3 test blocks to: ${PLUGIN_DIR}/example/integration_test/${PLUGIN_NAME}_test.dart"

# Step A-4: Validate (dry-run)
echo ""
echo "5. Validating tests (dry-run)..."
echo "   Command: flutter-tizen drive \\"
echo "     --driver=test_driver/integration_test.dart \\"
echo "     --target=integration_test/${PLUGIN_NAME}_test.dart \\"
echo "     -d $DEVICE_ID"
echo ""
echo "   Expected: All tests pass ✓"

# Step A-5: Commit (dry-run)
echo ""
echo "6. Commit (dry-run)..."
echo "   git add ${PLUGIN_DIR}/example/integration_test/ ${PLUGIN_DIR}/CHANGELOG.md"
echo "   git commit -m \"[${PLUGIN_NAME}] Add integration tests based on upstream v${TARGET_VERSION}\""
echo ""
echo "=== Path A workflow complete ==="
