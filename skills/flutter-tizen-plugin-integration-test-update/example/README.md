# Example: Update integration tests for Flutter-Tizen plugins

End-to-end workflows demonstrating integration test updates for both Flutter-based (Path A) and Tizen-only (Path B) plugins.

## Files

- `update_path_a.sh` — Path A workflow: port upstream tests for a Flutter-based plugin (audioplayers).
- `update_path_b.sh` — Path B workflow: write regression tests for a Tizen-only plugin (messageport).

## Scenario

**Path A (Flutter-based)**: You have the `audioplayers_tizen` plugin (`packages/audioplayers/`) wrapping the upstream `audioplayers` package. The upstream has 8 integration tests, but your Tizen file only has 5. The script shows how to identify missing tests, port them, and validate.

**Path B (Tizen-only)**: You have the `messageport_tizen` plugin (`packages/messageport/`), a Tizen-only plugin with no corresponding upstream. The script demonstrates API inventory, test design, and validation for full coverage of the public surface.

Both scripts are dry-run examples (they show the commands but use mock data). Adapt the device ID, paths, and assertion logic for your actual plugins.
