# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

A **content** repo, not an app. It ships Agent Skills that teach AI agents Tizen-specific Flutter
workflows — one directory under `skills/` each, all of them listed in `resources/flutter_tizen_skills.yaml`. It is the Tizen companion to [flutter/agent-plugins](https://github.com/flutter/agent-plugins)
(general Flutter) — only Tizen-specific knowledge belongs here.

The deliverable is `skills/<skill-name>/SKILL.md` plus an optional `example/` folder, and `rules/` for
the invariants a per-task skill cannot enforce (a skill loads only when its description matches, so
"always use `flutter-tizen`, never `flutter`" has to be an always-on rule). Everything under `tool/` is
generation and validation machinery. `rules/*.md` is the portable form; the `.mdc` twin is the Cursor
format — keep the two bodies identical.

## Generation pipeline

```
resources/flutter_tizen_skills.yaml     source of truth: name, description, examplePrompt,
        │                               instructions, doc URLs to crawl
        │  tool/generator  (Gemini; fetches each `resources:` URL)
        ▼
skills/<name>/SKILL.md                  generated, then hand-corrected
        │  tool/dart_skills_lint
        ▼
CI: .github/workflows/skill_lint.yaml
```

**Both directions matter.** SKILL.md files are hand-edited after generation, so a fix in a SKILL.md must
be mirrored back into that entry's `instructions:` in the YAML (see `43a6a33`), otherwise the next
`generate-skill` run silently reverts it. For small corrections, editing SKILL.md + YAML by hand is the
normal path — regeneration needs `GEMINI_API_KEY` and hallucinates Tizen CLI flags, plugin names, and
privilege URLs, so every generated output needs a hand review.

## Commands

Dart pub workspace (root `pubspec.yaml` → `tool/generator`, `tool/dart_skills_lint`), SDK `^3.10.8`.

```bash
dart pub get                       # root: resolves the whole workspace

# Lint every SKILL.md — run it exactly like CI does. The rule config lives in
# tool/dart_skills_lint/dart_skills_lint.yaml and is only loaded from that cwd,
# so running from the repo root silently drops check-relative-paths.
cd tool/dart_skills_lint && dart run bin/cli.dart -d ../../skills
dart run bin/cli.dart -d ../../skills --fix --dry-run   # preview autofixes
dart run bin/cli.dart -d ../../skills --fix             # apply them (--fix-apply is a deprecated alias)

# Regenerate a SKILL.md (needs GEMINI_API_KEY); --dry-run fetches + counts tokens only
dart run tool/generator/bin/skills.dart generate-skill resources/flutter_tizen_skills.yaml \
    --directory skills --skill flutter-tizen-device

# Do NOT run update-readme against this README — it only splices into a section titled
# "Available Skills" / "List of Skills" / "Skills List" / "Skill Index". Ours is "## Skills"
# (plus a second table for open-source-dev skills), so the command appends a duplicate
# "## Available Skills" section at the end instead. Edit the tables by hand.
dart run tool/generator/bin/skills.dart update-readme resources/flutter_tizen_skills.yaml \
    --directory skills --readme README.md

# Tool tests (there are no tests over skills/ content itself)
cd tool/dart_skills_lint && dart test
cd tool/dart_skills_lint && dart test test/fixer_test.dart -N 'partial test name'
cd tool/generator && dart test
dart analyze && dart format .      # run inside each tool/ package
```

`-d` means different things per tool: `--skills-directory` for the linter, `--directory` (output dir) for
the generator.

## SKILL.md contract

- Frontmatter: `name` (must equal the directory name), `description` (what it does + `Use when …`
  triggers; capped by the `description-too-long` rule), `metadata: {target, category, last_modified}`.
  Extra top-level keys are rejected (`disallowed-field`); metadata shape is checked by
  `valid-yaml-metadata`.
- Body style comes from `tool/generator/lib/src/services/skill_instructions.dart`: gerund H1
  ("Connecting, running, and logging Tizen targets"), imperative mood, self-contained single file (no
  links out to sibling docs), `## Workflow` sections with copyable `Task Progress` checklists, and a
  `## Common failures` symptom / cause / fix table.
- `check-relative-paths` and `check-absolute-paths` are `error` here, so every Markdown link must resolve
  on disk. Don't link into `example/` unless the path is exact.
- `example/` holds runnable companion material (shell scripts, `.dart`, `*.snippet.xml`) plus its own
  README describing the scenario. The root `analysis_options.yaml` excludes `skills/**/example/**`, so
  example Dart is **not** compile-checked — verify API usage by hand against the current Flutter version
  (a deprecated `Focus.onKey` shipped that way, `e40feb1`).

## Domain facts that keep breaking the content

Recurring source of bugs. Check any new or edited skill against these:

- **TV `sdb` is locked down.** On Samsung TV targets `sdb capability` reports `secure_protocol:enabled`
  and `intershell_support:disabled`, so `sdb dlog` / `sdb shell` return nothing **silently**. All log
  guidance must read the foreground `flutter-tizen run` console. Grepping dlog/logcat patterns
  (`E/FlutterEngine`, `F/`) matches an empty stream and reports a false PASS (`8f08608`).
- **Never `flutter pub get`** — always `flutter-tizen pub get`; vanilla Flutter does not register the
  Tizen platform interface. Same for `run`, `build`, `drive`, `test`.
- **Most `*_tizen` plugins are unendorsed**, so both the base package and the `_tizen` sibling must be
  added or every call throws `MissingPluginException`. Never name a package without confirming it exists
  in `flutter-tizen/plugins` (`e85a6e7` removed several that never existed).
- `flutter-tizen build tpk --device-profile` defaults to `tv` — always pass it explicitly. `x64` needs
  `api-version` ≥ `8.0` in `tizen-manifest.xml`. Read device arch with
  `sdb -s <id> capability | grep cpu_arch`, never `uname -m` (blocked on secured TV images).
- `flutter-tizen run` stays attached until `q`, so unattended/scripted runs must bound it with `timeout`
  or background-and-kill.
- Privileges in `tizen/tizen-manifest.xml` do not hot-reload; a manifest change needs a rebuild+reinstall.

## tool/ is vendored

`tool/generator` and `tool/dart_skills_lint` are copies from flutter/agent-plugins
(`dart_skills_lint` 0.4.0, sync commit `a8b86b3`). Fix bugs upstream and re-sync instead of diverging —
local edits are lost on the next sync, and the "Dart project authors" file headers there are intentional.
`dart_skills_lint/RULES.md` is pinned to `lib/src/rule_registry.dart` by `test/rules_md_consistency_test.dart`;
a rule change must update both in the same commit.

## Conventions

- Conventional Commits, scoped by skill name minus the `flutter-tizen-` prefix:
  `fix(tv-remote-input): …`, `docs(setup): …`, `fix(regression-test): …`.
- External PRs are not accepted yet (`CONTRIBUTING.md`) — file issues instead.
- License headers: `resources/*.yaml` carries the Flutter-Tizen authors BSD header and Dart files under
  `tool/` carry the Dart authors one. `SKILL.md` files and `example/` scripts carry none — don't add any.
- Nothing validates `rules/`. CI (`.github/workflows/skill_lint.yaml`) triggers only on `skills/**`,
  `resources/flutter_tizen_skills.yaml`, and `tool/dart_skills_lint/**`, and the linter only reads
  `SKILL.md`. A rule and its `.mdc` twin drifting apart is caught by review or not at all.
