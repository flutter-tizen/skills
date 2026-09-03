---
name: flutter-tizen-plugin-integration-test-update
description: Updates integration test cases for Flutter-Tizen plugins listed in .github/recipe.yaml. For Flutter-based plugins (Path A), ports Tizen-runnable tests from the upstream package at the exact version the Tizen plugin targets -- adding missing tests incrementally when the structure matches, or replacing the Tizen file wholesale from upstream when it differs significantly (preserving Tizen-unique cases), and consolidating multiple upstream test files into one. For Tizen-only plugins (Path B), writes regression tests covering the public API. Validates on a device or emulator -- a reproducing failure is fixed in the plugin's lib/ or tizen/ code when feasible, otherwise only that test case is removed. A lib/tizen change bumps the plugin version; a test-only change gets a CHANGELOG NEXT entry. Handles the 64-bit api-version bump and CA-matched signing the test run needs. Use when asked to add or update integration tests for Tizen plugins, or invoked as /flutter-tizen-plugin-integration-test-update [plugin_name].
metadata:
  target: flutter-tizen
  category: testing
  last_modified: Tue, 25 Aug 2026 00:00:00 GMT
---

# Updating Flutter-Tizen Plugin Integration Tests

## Goal

Write, validate, and commit integration test cases for Tizen plugins listed in `.github/recipe.yaml`.

---

## Step 0 — Identify Target Plugins and Select the Correct Path

1. Read `.github/recipe.yaml`. The testable plugins are those with a non-empty profile list (e.g., `["tv-9.0"]`).
2. If a specific `plugin_name` was passed as args, work on that plugin only. Otherwise, list the testable plugins and ask the user which one(s) to process.
3. Read `README.md` → "List of packages" table. For each target plugin, determine its type:
   - **Flutter-based**: has a "Frontend package" that is NOT "(Tizen-only)" → follow **Path A**
   - **Tizen-only**: Frontend package column says "(Tizen-only)" → follow **Path B**

> **CRITICAL — Path selection is a hard constraint, not a suggestion.**
>
> - **Path A** derives tests from the upstream integration test files. It does NOT invent tests based on personal judgment about uncovered API surface, even if such tests seem useful. Within Path A there are two modes selected by structural comparison (see A-2): **incremental add** (structure matches → add only the upstream tests missing from the Tizen file) and **wholesale replace** (structure differs significantly → regenerate the Tizen file from upstream). When upstream has **multiple** `*_test.dart` files, Path A consolidates them into a **single** Tizen `*_test.dart` entry.
> - **Path B** adds new tests based on API surface analysis. It applies to Tizen-only plugins. It is also the fallback for a Path A plugin whose upstream has **no** integration_test at all (see A-0).
>
> If a Flutter-based plugin (with upstream tests) needs API-coverage tests beyond what upstream provides, that is a separate task for the plugin owner, not part of this skill.

---

## Path A — Flutter-based Tizen Plugin

> **Path A scope reminder**: actions A-1 through A-5 derive their tests from the upstream integration test files. Do not invent test coverage from your own judgment about uncovered API surface. You MAY, however: (a) regenerate the Tizen file wholesale from upstream when the structure differs significantly (A-2 wholesale-replace mode), and (b) consolidate multiple upstream `*_test.dart` files into a single Tizen `*_test.dart` entry (A-2 / A-3). These restructurings are allowed because the test content still originates from upstream. The only hard prohibition is authoring tests that have no upstream origin — except in the A-0 fallback below.

### A-0. Handle the no-upstream-tests case

- If the upstream plugin at the target version has **no** `example/integration_test/` directory (or it contains no `*_test.dart` files), there is nothing to port. In that case, **fall back to Path B** (author Tizen regression tests from the public API surface) and note in the commit body that upstream had no integration tests.
- Otherwise, continue with A-1.

### A-1. Fetch the upstream original plugin at the version the Tizen plugin targets

- From the README table, find the `pub.dev` package name for the frontend package (e.g., `audioplayers`, `shared_preferences`).
- Determine the exact upstream version the Tizen plugin depends on:
  1. Read `packages/<plugin>/example/pubspec.yaml` and look for the frontend package under `dependencies:`.
  2. If pinned to an exact version (e.g., `audioplayers: 4.1.0`), use that version tag directly.
  3. If expressed as a range (e.g., `^4.1.0`), run `flutter-tizen pub deps` inside `packages/<plugin>/example/` and parse the resolved version from the output.
  4. Record the resolved version (e.g., `4.1.0`) — this is the **target version**.
- Fetch the integration test file(s) for **that exact target version** — never
  substitute a different version's tests. A different version can have a
  different API/test contract, silently porting tests that don't match the
  Tizen plugin's actual dependency and either testing the wrong behavior or
  failing to compile.
  - For every pub.dev package (1st- or 3rd-party): prefer the **pub.dev archive for the exact version**, which exists for every published version regardless of whether a matching git tag exists — fetch `https://pub.dev/api/archives/<pkg>-<version>.tar.gz` (equivalent content is browsable at `https://pub.dev/packages/<pkg>/versions/<version>`) and extract `example/integration_test/` from it. This guarantees the fetched tests match the target version's actual published API. If the package's pub.dev listing is discontinued or its `latest.version` is clearly stale relative to the target version, the archive fallback does not apply — treat this the same as "source cannot be obtained" below.
  - As a faster, human-readable alternative when a git tag for the **exact** target version reliably exists (commonly `<pkg>-v<version>` for flutter/packages, `v<version>` for others), fetch it via `raw.githubusercontent.com` instead — but only as a stand-in for the same content the pub.dev archive would give, not as an excuse to skip verifying the version matches.
  - Use WebFetch to retrieve the content.
  - **If the exact target version's source cannot be obtained** (pub.dev archive fetch fails and no matching git tag exists either), **stop and ask the user how to proceed** rather than silently falling back to an older or newer version — do not guess.

### A-2. Compare upstream tests vs Tizen tests, then select a mode

#### A-2a. Fetch upstream and identify the main test file

- Fetch **all** integration test files in the upstream `example/integration_test/` directory at the target version (not just one file).
- Identify the **main** `*_test.dart` file: the one that directly imports the plugin's public API (`package:<plugin>/<plugin>.dart`) and exercises its core functionality. This is usually `<plugin>_test.dart` or `lib_test.dart`. Treat app UI smoke tests (`app_test.dart`) and low-level platform-interface tests (`platform_test.dart`) as lower-priority **sub** files.
- Non-`*_test.dart` files (e.g. `test_utils.dart`, `*_test_data.dart`, `platform_features.dart`) are **helpers**, not test entry points — they are not counted here but may be ported as supporting files (see A-3).
- Read the Tizen integration test file: `packages/<plugin>/example/integration_test/<plugin>_test.dart`.

#### A-2b. Structural comparison → choose the mode

Compare upstream (main file first) against the Tizen file on **both structure and code content**. Classify as **"significantly different"** if **any** of the following holds:

- A shared helper layer (e.g. `PlatformFeatures`, centralized test-data providers) is present on one side but absent on the other.
- The `group` organization / naming scheme does not map between the two (cannot line tests up one-to-one).
- Tests covering the same feature differ at the level of a rewrite in their setup/teardown or assertion patterns (not a minor adaptation).

> The criteria above are the maintained definition — if you find a clearer or more robust signal while working, propose it rather than silently deviating.

Then branch:

- **Structure is similar → INCREMENTAL ADD mode** (default). Proceed with the diff table below, then A-3 incremental.
- **Structure differs significantly → WHOLESALE REPLACE mode.** Skip the diff table and go to A-3 wholesale replace.

#### A-2c. Diff table (INCREMENTAL ADD mode only)

List every `testWidgets` / `test` / `group` block across **all** upstream files and produce:

  | # | Test name (group > test) | Source upstream file | Present in upstream | Present in Tizen |
  |---|--------------------------|----------------------|--------------------|--------------------|
  | 1 | ...                      | lib_test.dart        | ✅                 | ❌ → **add**       |
  | 2 | ...                      | lib_test.dart        | ✅                 | ✅ → skip          |
  | 3 | ...                      | —                    | ❌                 | ✅ → Tizen-specific, keep |

- **Only rows marked "add" qualify for A-3.** Tests with no upstream origin must NOT be added (except via the A-0 fallback).
- Process the **main** file's "add" rows first, then sub files' "add" rows sequentially.
- If there are no "add" rows, report "No new test cases to add" and stop.

### A-3. Produce the Tizen test file (mode-dependent)

**Tizen-runnable filter (applies to both modes).** Include a test case only if it can actually run on Tizen. Exclude tests that:
- Require features unavailable on Tizen (camera, GPS, platform-specific hardware).
- Have OS-version checks that don't apply to Tizen.
- Are gated to other platforms (`skip: !Platform.isAndroid`, `skip: !Platform.isMacOS`, etc.) — **unless the test still runs correctly on Tizen**, in which case keep it and adjust/remove the gate so it executes on Tizen. The decision is "does it work on Tizen?", not "is it labeled platform-specific?".

**Adaptation rules (both modes).** Adapt only what is strictly necessary to compile and run on Tizen:
- Replace infrastructure helpers (e.g. `PlatformFeatures`, `getAudioTestDataList`) with Tizen-compatible equivalents, or inline equivalents using locally available assets.
- Preserve the Samsung copyright header; fix imports (add only what new tests require, drop unused).
- Do not add tests that have no upstream origin (except the A-0 fallback).

**Single-file rule (both modes).** The Tizen plugin keeps exactly **one** `*_test.dart` entry point: `packages/<plugin>/example/integration_test/<plugin>_test.dart`. Non-`*_test.dart` helper files (test utils, test data) may live as separate supporting files if useful — the constraint is on the number of `*_test.dart` entry points, not helpers.

**Tizen-only tests go last (both modes).** Any test with no upstream counterpart — a preserved Tizen-unique case, or one added to cover a Tizen-specific fix — must be appended at the **end of `main()`**, after all upstream-derived tests, with a short comment marking it Tizen-only. Ported tests must stay in upstream's order and position. Interleaving a Tizen-only test among them makes the next upstream sync conflict on unrelated hunks.

**Mirror upstream's async style exactly.** When a ported test uses `unawaited(...)`, keep `unawaited(...)`; when it awaits, keep the await. Do not "normalize" one to the other for internal consistency — upstream sometimes deliberately mixes them within a file (e.g. `webview_flutter`'s two `onHttpError` tests leave `setJavaScriptMode`/`setNavigationDelegate`/`loadRequest` unawaited while every other test awaits). Diverging here creates review churn and sync conflicts for no behavioral gain. If a reviewer or bot flags the inconsistency, answer with the upstream file and line rather than changing it.

#### A-3a. INCREMENTAL ADD mode

For each "add" row from A-2c (main file first, then sub files in sequence):
- Copy the test block from upstream into the Tizen file at the appropriate location, preserving `group` structure.
- When merging sub-file tests, resolve name collisions by wrapping them in a `group()` that namespaces them (e.g. by their source file's concern).
- Apply the Tizen-runnable filter and adaptation rules above.

#### A-3b. WHOLESALE REPLACE mode

- Regenerate the Tizen `<plugin>_test.dart` from the upstream files: start from the **main** file's structure, then fold in Tizen-runnable test cases from the **sub** files sequentially (namespacing via `group()` as needed), so the result is a single consolidated file.
- Apply the Tizen-runnable filter and adaptation rules to every ported test.
- **Preserve Tizen-unique coverage.** Before discarding the old Tizen file, compare its tests against the regenerated upstream-derived suite. A test that exists only in the old Tizen file **and** covers behavior the upstream suite does NOT cover must be kept — append it at the end, clearly marked as Tizen-specific. Drop only the old Tizen-only tests that are already covered (redundant) by the upstream suite. Note in the commit body which Tizen-specific tests were preserved (or that none were needed).
- Apart from preserved Tizen-unique tests, the old Tizen file content is superseded by the regenerated file.

### A-4. Validate and resolve failures

Run the suite on a connected device or emulator:
```
flutter-tizen drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/<plugin>_test.dart \
  -d <device_id>
```

> **Use `drive`, never `flutter-tizen test`.** `flutter-tizen test
> integration_test/<plugin>_test.dart` can fail to even load the suite, before
> any test runs, with `Bad state: Can't call test() once tests have begun
> running` pointing at the first `testWidgets`. This happens whenever `main()`
> awaits something (e.g. `await HttpServer.bind(...)`) before declaring its
> tests — a structure several upstream suites use, so it is not a defect in the
> ported file. The same suite runs fine under `drive`. If you see this error, do
> not restructure `main()` and do not blame your change: switch to `drive`.

> **Get a baseline before blaming your change.** When the suite fails in a way
> that looks environmental (fails to load, install rejected, app dies at
> startup), `git stash` your changes and run the same command on a clean HEAD
> first. An identical failure means the cause is the environment or a
> pre-existing issue, and chasing it inside your diff wastes a full
> build-install-run cycle each time. Also run one target at a time — concurrent
> runs against the same emulator interfere with each other.

> **A single green run does not prove a disposal/threading fix.** Test order
> perturbs timing enough to hide real races. A concrete case: a plugin build
> with a genuine raster-thread use-after-free passed 20/20 with a Tizen-only
> test sitting between two upstream tests, and crashed deterministically once
> that same test moved to the end of `main()` — no C++ change at all. So when
> the change under test touches disposal, threading, or texture/buffer
> lifetime: keep Tizen-only tests at the end of `main()`, and re-run the suite
> **3+ times** before calling it verified. Report the run count in the
> validation report, not just "passing".

> **Target architecture / api-version (both paths).** Before running, check the
> target's CPU architecture — `sdb -s <device_id> capability` (look at
> `cpu_arch`) or `sdb -s <device_id> shell uname -m`. **64-bit targets**
> (`aarch64`/`arm64`, `x86_64`/`x64`) require the app's `api-version` to be
> **≥ 8.0**; otherwise the build fails with e.g. `Error: x64 is not supported
> with API version < 8.0`. If the target is 64-bit and
> `packages/<plugin>/example/tizen/tizen-manifest.xml` has `api-version` below
> `8.0`, **temporarily** raise it to `8.0` for the test run, then **restore the
> original value** once testing finishes (whether it passed or failed). This
> temporary edit is only to let the test run on a 64-bit target — never commit
> it. (32-bit targets such as `armv7l`/`x86` have no such restriction.)

> **Signing certificate / security profile (both paths).** The TPK must be
> signed with a certificate whose root CA matches the **target family**, or the
> install is rejected with `install failed[118, -12], reason: Check certificate
> error` (the build succeeds; only the on-device install fails). The mapping is:
>
> - **Samsung TV devices _and_ the TV emulator** → a certificate based on the
>   **Samsung VD Author CA** (a Samsung-issued VD/partner author certificate).
> - **Raspberry Pi (and other plain real Tizen devices) _and_ the standard
>   Tizen emulator** → a certificate based on the **Tizen Developers CA** (the
>   default Tizen author certificate).
>
> `flutter-tizen` always signs with the **active** Tizen security profile (there
> is no per-run `--security-profile` flag on `flutter-tizen drive`). Before
> running, list the profiles with `tizen security-profiles list` and make sure
> the active profile's author certificate was issued by the CA matching your
> target family. If it does not match, either switch the active profile to one
> that does — `tizen security-profiles set-active -n <profile_name>` — or pick a
> connected target whose family matches the currently active profile. A
> `Check certificate error` is an environment/signing mismatch, **not** a test
> or plugin failure: fix the profile (or change target) and re-run; never remove
> a test or weaken an assertion over it.

Retry a flaky/transient failure up to **3 times**. For a failure that
**reproduces**, diagnose the root cause and resolve it with the
**failure-resolution policy** below, then re-run to confirm. Iterate until the
suite is green (all remaining tests pass; 0 failures).

> **Failure-resolution policy (applies to Path A and Path B).** For each
> reproducing failed test case:
>
> 1. **Plugin-fixable → fix the plugin and KEEP the test.** If the root cause
>    is a bug or gap in the Tizen plugin's own code — Dart under
>    `packages/<plugin>/lib/`, or native code under `packages/<plugin>/tizen/`
>    — and a correct, behavior-faithful fix is feasible, fix the plugin code,
>    re-validate, and keep the test case. Prefer aligning Tizen behavior with
>    other platforms; do NOT weaken the test's assertions just to force a pass.
> 2. **Not fixable → remove ONLY that test case.** If the failure stems from a
>    genuine limitation the plugin cannot reasonably resolve (missing Tizen/OS
>    capability, unavailable hardware, network/emulator constraint, behavior
>    that cannot be made correct), remove just that failing test case. Do NOT
>    revert the whole file or drop other passing tests.
>
> After every fix or removal, re-run to confirm the suite is green. Record, for
> each failure, whether it was **kept via a plugin fix** (and what changed) or
> **removed** (and why) — see the Validation Report in the Reporting section.

> **Comment style for plugin fixes (reviewer-mandated).** When option 1 changes
> `lib/` or `tizen/` code, keep the comments minimal. Maintainer guidance on
> flutter-tizen/plugins is: *"Please delete all unnecessary comments. If you
> wish to explain how X works, leave the explanation in the PR. Please only
> leave comments for parts that must be referenced for functionality (TODO,
> NOTE) or descriptions that need to be published."* Concretely:
>
> - **In code:** 1–3 lines, stating only a constraint a future editor could
>   otherwise violate — a required ordering, a thread affinity, a
>   deliberately-not-freed resource, a workaround with its trigger. Plus real
>   `TODO(name):` / `NOTE:` markers and doc comments on public API.
> - **In the PR description:** the narrative — why the race happens, the
>   lifetime diagram, the sequence of events, the alternatives rejected.
> - **Delete outright:** restatements of what the code already says, multi-
>   paragraph rationale blocks, and per-line commentary on obvious calls.
>
> Writing a long explanatory block first and then trimming it is fine — just do
> not ship it. A good check before staging: for each comment added, ask whether
> it would prevent a wrong edit. If not, it belongs in the PR body.

- On success (suite green): proceed to A-5.
- If, after applying the policy, some failures were resolved by plugin fixes
  and/or others removed, the suite must still end green before A-5.

### A-5. Commit

Before staging, verify formatting and static analysis pass:
```
dart format --output=none --set-exit-if-changed packages/<plugin>/
dart analyze packages/<plugin>/
```
If `dart format` reports changed files, apply formatting (`dart format packages/<plugin>/`) and re-verify. Fix any `dart analyze` errors before committing.

Stage the modified `<plugin>_test.dart` **and** any helper file added or
changed alongside it under A-3's single-file rule (test utils, test data) —
an orphaned helper left unstaged means the committed test file references
code that isn't in the repo. Also stage `CHANGELOG.md` — the "Version bump"
section below requires a `## NEXT` entry for a test-only change, and that
entry must be committed together with the test file. Then create a commit
with upstream version info:
```
git add packages/<plugin>/example/integration_test/ packages/<plugin>/CHANGELOG.md
git commit -m "[<package_name>] Add integration tests based on upstream v<version>

Add Tizen-compatible test cases ported from upstream <package_name> v<version>:
- <test case 1>
- <test case 2>
..."
```

**Key requirements** (also follow the shared **Commit message conventions** below):
- Include the exact upstream version (e.g., `v7.1.1`) in the commit title and body.
- List all added/ported test cases as bullet points in the commit body.
- Note that only tests that actually run on Tizen are included; list any tests that were left out because they don't apply to Tizen.
- If the test file was regenerated from the upstream suite, note (in plain language) that it now mirrors the upstream tests, and mention any Tizen-specific tests that were preserved because upstream doesn't cover them (or that none were needed).
- If failures were resolved by fixing plugin code (`lib/` or `tizen/`), commit that fix **separately** (e.g. `[<package_name>] Fix <issue> on Tizen`), mention in the test commit which tests it keeps passing, and **bump the plugin version before pushing** per "Version bump when plugin code is changed" below.
- Example: `[connectivity_plus] Add integration tests based on upstream v7.1.1`

---

## Path B — Tizen-only Plugin

### B-1. Inventory the public API

- List `packages/<plugin>/lib/` to find the entry-point Dart file — it's usually `<plugin>.dart`, but plugins whose pub package name carries a `_tizen` disambiguation suffix (e.g. `messageport` → `messageport_tizen.dart`) name the file after the pub package name instead. Read that file (or `lib/src/`) to enumerate all public classes, methods, getters, setters, and streams.
- Read the existing integration test file (if any): `packages/<plugin>/example/integration_test/<plugin>_test.dart`.
- Identify API surface **not yet covered** by existing tests.

### B-2. Write regression test cases

Design test cases following these principles:
- **Happy path**: each public method/getter called with valid inputs → assert expected return value or side effect.
- **Edge cases**: null-safe boundaries, empty collections, zero values, max/min values where relevant.
- **Error paths**: invalid arguments, operations on uninitialized state → assert that the correct exception type is thrown.
- **State transitions**: if the API has lifecycle (open/close, connect/disconnect), test the full sequence.
- **Idempotency**: calling read-only methods twice must return consistent results.

Use `testWidgets` for tests needing a widget tree; use plain `test()` otherwise. Group related tests under `group()` blocks.

Template per test:
```dart
testWidgets('<method> <expected behavior>', (WidgetTester tester) async {
  // arrange
  // act
  // assert
});
```

### B-3. Validate and resolve failures

Run the suite on a connected device or emulator:
```
flutter-tizen drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/<plugin>_test.dart \
  -d <device_id>
```

Before running, apply the **Target architecture / api-version** check from A-4
(temporarily raise `api-version` to 8.0 for 64-bit targets, then restore) and
the **Signing certificate / security profile** check from A-4 (active profile's
CA must match the target family — Samsung VD Author CA for TV, Tizen Developers
CA for RPi / standard emulator).
Retry a flaky/transient failure up to **3 times**. For a reproducing failure,
apply the **failure-resolution policy** defined in A-4: if the root cause is in
the Tizen plugin's own `lib/` (Dart) or `tizen/` (native) code and a faithful
fix is feasible, fix the plugin and **keep** the test; otherwise **remove only
that failing test case** (do not revert the whole file). Iterate until the
suite is green, then record kept-via-fix vs removed (Validation Report) and
proceed to B-4.

### B-4. Commit

Before staging, verify formatting and static analysis pass:
```
dart format --output=none --set-exit-if-changed packages/<plugin>/
dart analyze packages/<plugin>/
```
If `dart format` reports changed files, apply formatting (`dart format packages/<plugin>/`) and re-verify. Fix any `dart analyze` errors before committing.

Stage the modified/new integration test file, any helper file added alongside
it (test utils, test data), and `CHANGELOG.md` — the "Version bump" section
below requires a `## NEXT` entry for a test-only change, committed together
with the test file (and any plugin `lib/`/`tizen/` code changed under the A-4
policy — commit such a fix separately, and bump the plugin version per
"Version bump when plugin code is changed" below before pushing). Follow the
shared **Commit message conventions** below.
```
git add packages/<plugin>/example/integration_test/ packages/<plugin>/CHANGELOG.md
git commit -m "[<package_name>] Add regression integration tests"
```
- If the plugin has an upstream counterpart package whose API it follows (even
  when it is not a federated implementation, e.g. `device_info_plus`), include
  that upstream version in the message. Omit the version only for genuinely
  Tizen-exclusive plugins that have no upstream package.

---

## Commit message conventions

These apply to every commit this skill creates (both paths):

- **Write for a reader who does not know this skill.** Do NOT use any
  skill-internal terms in the commit message — e.g. "Path A", "Path B",
  "incremental add", "wholesale replace", "A-0 fallback", "Tizen-runnable
  filter". Describe what changed in plain language (e.g. "ported the upstream
  integration tests", "replaced the test file with the upstream test suite",
  "added regression tests for the public API").
- **Always record the upstream version** the tests/implementation were derived
  from, whenever the plugin has an upstream counterpart package — a frontend
  package OR a same-named pub.dev package whose API the Tizen plugin mirrors,
  even if the Tizen plugin is not a federated implementation (e.g.
  `device_info_plus`). Put it in the title (`... based on upstream v<version>`)
  and/or body. Determine the version from the example `pubspec.yaml`/`.lock`,
  the Tizen plugin's `pubspec.yaml`/`CHANGELOG`, or the upstream tag used.
- **Only omit the upstream version** for genuinely Tizen-exclusive plugins that
  have no upstream package at all.

---

## Version bump when plugin code is changed

If resolving a validation failure (A-4 / B-3) changed the plugin's own code —
anything under `packages/<plugin>/lib/` (Dart) or `packages/<plugin>/tizen/`
(native) — the plugin **must be version-bumped before the PR is pushed**.

**Test-only changes (only files under `example/integration_test/`) do NOT get a
version bump.** Instead, record them in `CHANGELOG.md` under a `## NEXT` entry
(added above the latest released version) that simply states how many
integration test cases were added/updated — e.g.:
```
## NEXT

* Add 2 integration test cases.
```
Do not change `pubspec.yaml` or the README version for a test-only change.

For a change that does bump the version, choose the bump with semantic
versioning:
- **patch** (`x.y.Z`): bug fixes / behavior corrections, no public API change.
- **minor** (`x.Y.z`): backward-compatible new API or behavior.
- **major** (`X.y.z`): breaking public API change.

Update these together and commit them **separately** from the test commit:
1. `packages/<plugin>/pubspec.yaml` — bump the `version:` field.
2. `packages/<plugin>/CHANGELOG.md` — add a new top entry `## <new version>`
   with one bullet per change, matching the existing entry style.
3. `packages/<plugin>/README.md` — update the hard-coded plugin version in the
   "Usage" section's dependency snippet if present (e.g.
   `<plugin>_tizen: ^<new version>`); many plugins pin the version there and it
   does NOT auto-update. Also update any documented behavior that changed (e.g.
   a now-resolved item in a "Limitations" / "Supported APIs" section). The
   pub.dev version badge auto-updates and never needs editing.

Commit message (no skill-internal terms), e.g.:
`[<package_name>] Bump <package_name> to <new version>`

---

## Validation Report Format

After A-4 / B-3 resolves failures, output a structured report covering how each
reproducing failure was handled (kept via a plugin fix, or removed):

```
## Integration Test Validation Report

**Plugin**: <plugin_name>
**Type**: Flutter-based | Tizen-only
**Date**: <date>
**Test file**: packages/<plugin>/example/integration_test/<plugin>_test.dart
**Final result**: <N passed, M skipped, 0 failed>

### Kept via plugin fix
| Test name | Root cause | Fix (file + summary) |
|-----------|------------|----------------------|
| ...       | ...        | tizen/src/foo.cc: ... |

### Removed (not Tizen-runnable)
| Test name | Root cause | Why a plugin fix was not feasible |
|-----------|------------|-----------------------------------|
| ...       | ...        | ...                               |
```

If every failure was resolved (fixed or removed) and the suite is green, this
report documents the outcome. If a failure could neither be fixed nor cleanly
removed, explain it here and stop rather than committing a red suite.

---

## Quality Checklist (run before committing)

- [ ] All added tests have a descriptive name following the pattern `'<subject> <expected outcome>'`
- [ ] No test imports unused packages
- [ ] No hardcoded device paths or credentials
- [ ] `IntegrationTestWidgetsFlutterBinding.ensureInitialized()` is called in `main()`
- [ ] Copyright header is present: `// Copyright <year> Samsung Electronics Co., Ltd.`
- [ ] `dart format --output=none --set-exit-if-changed packages/<plugin>/` reports no changes
- [ ] `dart analyze packages/<plugin>/` passes with no new errors
- [ ] **If the plugin version was bumped**: verify that all three files agree on the new version:
  - `packages/<plugin>/pubspec.yaml` — `version:` field
  - `packages/<plugin>/CHANGELOG.md` — topmost `## <version>` heading
  - `packages/<plugin>/README.md` — version in the `pubspec.yaml` dependency snippet (e.g. `<plugin>_tizen: ^<new version>`)

---

## Notes

- Device ID can be obtained with `sdb devices`; pass it via `-d <serial>`.
- The drive command targets the test via `--target`; the driver file is always `test_driver/integration_test.dart`.
- Do **not** modify `test_driver/integration_test.dart` — it is shared boilerplate.
- When fetching upstream files via WebFetch, prefer the `raw.githubusercontent.com` URL for plain-text content.
- Testable plugins (those with a non-empty profile list in `recipe.yaml`) are the only candidates for this workflow; skip plugins with `[]`.
- For flutter-tizen conventions (plugin development, commands, device setup) when unsure, consult the AI-rules doc in the flutter-tizen checkout — the `doc/` folder beside the `bin/flutter-tizen` on PATH, i.e. `"$(dirname "$(dirname "$(command -v flutter-tizen)")")/doc/flutter-tizen-ai_rules_10k.md"`. Read it **on demand only** (not preemptively) and prefer this condensed `_10k` version to keep token use low; fall back to the full `flutter-tizen-ai_rules.md` only if the condensed one is insufficient.
