# Flutter-Tizen Agent Skills

AI agent skills for [flutter-tizen](https://github.com/flutter-tizen/flutter-tizen). This skill set, maintained by the Flutter-Tizen team, provides guidelines designed for common workflows in Flutter app development for Tizen.

Provides Tizen-specific skills. Use with [flutter/agent-plugins](https://github.com/flutter/agent-plugins) for general Flutter development.

## Skills

| Skill                                                                          | Description                                       |
| ------------------------------------------------------------------------------ | ------------------------------------------------- |
| [flutter-tizen-setup](skills/flutter-tizen-setup/SKILL.md)                     | Install and verify Tizen SDK toolchain            |
| [flutter-tizen-build-tpk](skills/flutter-tizen-build-tpk/SKILL.md)             | Build, sign, and inspect TPK packages             |
| [flutter-tizen-device](skills/flutter-tizen-device/SKILL.md)                   | Connect devices via sdb, run apps, filter dlog    |
| [flutter-tizen-tv-remote-input](skills/flutter-tizen-tv-remote-input/SKILL.md) | Handle D-pad focus and remote key input           |
| [flutter-tizen-use-plugins](skills/flutter-tizen-use-plugins/SKILL.md)         | Use `*_tizen` plugins with privilege declarations |
| [flutter-tizen-create-plugin](skills/flutter-tizen-create-plugin/SKILL.md)     | Create C++ native plugins with method channels    |


### For opensource dev
| Skill                                                                          | Description                                       |
| ------------------------------------------------------------------------------ | ------------------------------------------------- |
| [flutter-tizen-plugin-regression-test](skills/flutter-tizen-plugin-regression-test/SKILL.md) | Run regression tests for flutter-tizen plugins |
| [flutter-tizen-plugin-integration-test-update](skills/flutter-tizen-plugin-integration-test-update/SKILL.md) | Update integration test cases for flutter-tizen plugins |

## Install

```bash
# Install all skills
npx skills add flutter-tizen/skills --skill '*' --agent universal

# Install specific skills
npx skills add flutter-tizen/skills --skill flutter-tizen-setup,flutter-tizen-build-tpk

# Global install
npx skills add flutter-tizen/skills --skill '*' --global

# Update
npx skills update
```

For manual install, copy or symlink `skills/flutter-tizen-*/` folders to your target directory.

## Maintainers

```bash
# Lint
cd tool/dart_skills_lint
dart run bin/cli.dart -d ../../skills

# Regenerate SKILL.md (requires GEMINI_API_KEY)
dart run tool/generator/bin/skills.dart generate-skill \
  resources/flutter_tizen_skills.yaml \
  --directory skills
```

> **Note:** The `tool/` directory (skill generator and linter) is sourced from [flutter/agent-plugins](https://github.com/flutter/agent-plugins) and kept in sync with its upstream updates.

## License

[BSD 3-Clause License](LICENSE)
