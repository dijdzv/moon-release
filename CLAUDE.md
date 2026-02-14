# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Language

Respond in Japanese. Technical terms and code identifiers remain in their original form.

## Build & Test Commands

```bash
# Build & check (native target only)
moon build --target native           # Build executable (debug)
moon build --target native --release # Build executable (release, optimized)
moon check --target native           # Type-check only (fast)

# Test
moon test --target native            # Unit tests (485+ tests)
./tests/integration/run_tests.sh     # E2E tests (58+ tests, builds binary first)

# Run
moon run src -- <args>               # Run CLI directly
# or after build:
./_build/native/release/build/moon-release.exe <args>
```

The `justfile` provides shortcuts: `just test`, `just test-integration`, `just test-all`, `just check`, `just build-native`.

## Architecture

MoonBit release automation tool. CLI dispatches commands via `TheWaWaR/clap` parser.

### Package Dependency Flow

```
src/               CLI entry point, command handlers, completions, schema
  └── lib/workflow/      Orchestrates release operations (PR, tag, publish)
        ├── lib/executor/      Subprocess execution (git, gh, moon CLI)
        ├── lib/github/        GitHub API via gh CLI
        ├── lib/semver_check/  API compatibility detection via moon doc
        ├── lib/git/           Git repository operations
        ├── lib/moon_mod/      moon.mod.json parser
        ├── lib/config/        release.json parsing & Config struct
        ├── lib/semver/        SemVer parsing, comparison, bumping
        ├── lib/conventional/  Conventional Commits parser
        └── lib/util/          JSON helpers, path validation
```

### Native/Stub Target Split

This project targets **native only**. wasm-gc/js are not used for building or testing.

executor, workflow, and the root package (src/) have stub files (`stub.mbt`) declared for `["wasm", "wasm-gc", "js"]` in `moon.pkg` `targets`. These exist solely because MoonBit requires all targets to compile — the stubs just raise errors and are never executed.

When modifying struct fields or function signatures in native code, **always update the corresponding stub.mbt** to keep them in sync (otherwise `moon check` will fail).

### Config → Context Flow

1. `release.json` → `@config.Config::parse()` → `Config` struct
2. CLI flags merge with config (e.g., `bump_all = config.bump_all_packages || cli_flag`)
3. `ReleaseContext::new()` bundles config + repo + versions + flags
4. Workflow functions receive context and execute operations

### Monorepo Version Logic

Three functions share the same 3-phase pattern (must stay in sync):
- `get_monorepo_representative_version` — computes tag/branch version
- `run_update_packages` — writes version files
- `collect_package_release_info` — generates PR body

Each follows: Phase 1 (collect per-package info) → Phase 2 (consolidate by `version_group`) → Phase 3 (apply final bump types).

## MoonBit Language Notes

- Named/optional params: `fn foo(x~ : Bool = false)` called as `foo(x=true)`
- Error handling: `try { ... } catch { ... } noraise { ... }` pattern
- `String.split()` returns `Iter[StringView]` — use `.to_string()` to convert
- `\\` in string literals is escape for single `\`
- Test files use `_wbtest.mbt` suffix (white-box tests)
- Multi-line string literals use `#|` prefix per line

## Test Expectations

- **Unit tests** (`moon test --target native`): 485+ tests, 0 failures. 3 warnings (`unused_error_type`) are expected.
- **Integration tests** (`./tests/integration/run_tests.sh`): 58+ tests, builds binary automatically before running. 2 tests require `gh auth` and are skipped otherwise.
