# moon-release

Automated release management tool for MoonBit projects. Inspired by [release-plz](https://github.com/release-plz/release-plz), optimized for the MoonBit ecosystem.

## Features

- **Conventional Commits** - Automatically determine semantic version from commits
- **GitHub Release** - Automatic creation of tags and release notes
- **Release PR** - Automatic creation and update of release pull requests
- **mooncakes.io** - Automatic publishing to the MoonBit package registry
- **API Compatibility Check** - semver-checks for breaking change detection
- **Monorepo Support** - Version synchronization via version_group

## Installation

```bash
# Build from source
git clone https://github.com/dijdzv/moon-release
cd moon-release
moon build --target native

# Add binary to PATH
cp target/native/release/build/src/main/main.exe ~/.local/bin/moon-release
```

## Quick Start

```bash
# Initialize configuration file
moon-release init

# Check current state
moon-release check

# Preview version update
moon-release update --dry-run

# Update version
moon-release update

# Create release PR
moon-release release-pr

# Create release (tag + GitHub Release + publish)
moon-release release
```

## Commands

### `moon-release check`

Check the current state and display recommended version bump.

```bash
moon-release check
moon-release check --verbose  # Show commit details
moon-release check -o json    # Output in JSON format
```

### `moon-release update`

Update the version in `moon.mod.json` (no commit/push).

```bash
moon-release update              # Auto-determine
moon-release update --bump major # Force major bump
moon-release update --dry-run    # Preview only
moon-release update -o json      # Output in JSON format
```

### `moon-release release-pr`

Create or update a release Pull Request.

```bash
moon-release release-pr
moon-release release-pr --dry-run
```

### `moon-release release`

Create Git tag and GitHub Release, and publish to mooncakes.io.

```bash
moon-release release
moon-release release --prerelease alpha  # Prerelease
moon-release release --dry-run
```

### `moon-release set-version`

Manually set the version.

```bash
moon-release set-version 1.0.0
```

### `moon-release init`

Create the configuration file `release.json`.

```bash
moon-release init
moon-release init --force  # Overwrite
```

### `moon-release generate-completions`

Generate shell completion scripts.

```bash
moon-release generate-completions bash > ~/.local/share/bash-completion/completions/moon-release
moon-release generate-completions zsh > ~/.zfunc/_moon-release
moon-release generate-completions fish > ~/.config/fish/completions/moon-release.fish
```

### `moon-release generate-schema`

Generate JSON Schema for the configuration file. Can be used for IDE autocompletion.

```bash
moon-release generate-schema > release-schema.json
```

## Configuration

Customize behavior with `release.json`.

```json
{
  "pr_title": "chore: release v{{ version }}",
  "pr_draft": false,
  "pr_labels": ["release"],
  "pr_body": "## Release v{{ version }}",
  "pr_branch_prefix": "release/",
  "base_branch": "main",
  "allow_prerelease": false,
  "git_tag_enable": true,
  "git_tag_name": "v{{ version }}",
  "git_release_enable": true,
  "git_release_draft": false,
  "git_release_name": "Release v{{ version }}",
  "git_release_body": "{{ changelog }}",
  "git_release_latest": true,
  "publish": true,
  "publish_frozen": false,
  "publish_timeout": 300,
  "semver_check": true,
  "registry_check": false,
  "allow_dirty": false,
  "custom_major_increment_regex": null,
  "custom_minor_increment_regex": null,
  "max_analyze_commits": null,
  "packages": []
}
```

### Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| `pr_title` | `"chore: release v{{ version }}"` | PR title template |
| `pr_draft` | `false` | Create as draft PR |
| `pr_labels` | `[]` | Labels to add to PR |
| `pr_body` | - | PR body template |
| `pr_branch_prefix` | `"release/"` | Release branch prefix |
| `base_branch` | `"main"` | PR base branch |
| `git_tag_enable` | `true` | Whether to create Git tag |
| `git_tag_name` | `"v{{ version }}"` | Tag name template |
| `git_release_enable` | `true` | Whether to create GitHub Release |
| `git_release_draft` | `false` | Create as draft release |
| `git_release_name` | `"Release v{{ version }}"` | Release name template |
| `git_release_body` | `null` | Release body template (null for auto-generate) |
| `git_release_latest` | `true` | Mark GitHub Release as latest |
| `publish` | `true` | Whether to publish to mooncakes.io |
| `publish_frozen` | `false` | Use `moon publish --frozen` |
| `publish_timeout` | `300` | Publish timeout in seconds (future implementation) |
| `semver_check` | `false` | Run API compatibility check |
| `registry_check` | `false` | Check registry version before publish |
| `allow_dirty` | `false` | Allow uncommitted changes |
| `custom_major_increment_regex` | `null` | Custom regex for major bump |
| `custom_minor_increment_regex` | `null` | Custom regex for minor bump |
| `max_analyze_commits` | `null` | Maximum number of commits to analyze |

### Template Variables

| Variable | Description |
|----------|-------------|
| `{{ version }}` | New version number |
| `{{ changelog }}` | Auto-generated release notes (`git_release_body` only) |

## Conventional Commits

moon-release parses [Conventional Commits](https://www.conventionalcommits.org/) to automatically determine the version.

| Commit Type | Bump | Example |
|-------------|------|---------|
| `feat` | Minor | `feat: add new feature` |
| `fix` | Patch | `fix: resolve bug` |
| `feat!` / `fix!` | Major | `feat!: breaking change` |
| `BREAKING CHANGE:` | Major | In footer |

Other types (`docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`) do not affect the version.

## API Compatibility Check (semver_check)

Setting `semver_check: true` detects breaking API changes before release.

```json
{
  "semver_check": true
}
```

### Detected Changes

| Change | Impact |
|--------|--------|
| Removal of pub type/function/method | Breaking (Major) |
| Signature change | Breaking (Major) |
| Struct field removal/change | Breaking (Major) |
| Addition of new pub type/function | Addition (Minor) |

### How It Works

1. Checkout latest tag → Generate API with `moon doc`
2. Return to current code → Generate API with `moon doc`
3. Compare the two `package_data.json` files
4. Display warning if breaking changes are found

## Monorepo Support

For monorepos with multiple packages, configure each package individually with `packages`.

```json
{
  "packages": [
    {
      "name": "core",
      "path": "packages/core",
      "publish": true,
      "version_group": "main"
    },
    {
      "name": "utils",
      "path": "packages/utils",
      "publish": true,
      "version_group": "main"
    },
    {
      "name": "internal",
      "path": "packages/internal",
      "publish": false
    }
  ]
}
```

### version_group

Packages with the same `version_group` are aligned to the largest bump type within the group.

Example: If `core` has a breaking change and `utils` has a feat, both will receive a major bump.

## GitHub Actions

### Basic Usage

```yaml
name: Release

on:
  push:
    branches: [main]

permissions:
  contents: write
  pull-requests: write

jobs:
  release-pr:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: dijdzv/moon-release@main
        with:
          command: release-pr
          github-token: ${{ secrets.GITHUB_TOKEN }}
```

### Auto-publish to mooncakes.io

To automatically publish to mooncakes.io, you need to configure authentication.

#### 1. Get Token

```bash
# Authenticate locally
moon login

# Check token
cat ~/.moon/credentials.json
# {"token": "xxxxx", "username": "your-username"}
```

#### 2. Configure GitHub Secrets

In your repository's Settings → Secrets and variables → Actions, set:

- `MOONCAKES_TOKEN`: The `token` value from credentials.json
- `MOONCAKES_USERNAME`: The `username` value from credentials.json

#### 3. Configure Workflow

```yaml
- uses: dijdzv/moon-release@main
  with:
    command: release
    github-token: ${{ secrets.GITHUB_TOKEN }}
    mooncakes-token: ${{ secrets.MOONCAKES_TOKEN }}
    mooncakes-username: ${{ secrets.MOONCAKES_USERNAME }}
```

> **⚠️ Security Notice**
>
> mooncakes.io does not currently provide limited-scope tokens for CI use.
> The token in `~/.moon/credentials.json` may have full account permissions.
> Use at your own risk with this understanding.

### Workflow Template

Copy [templates/release.yml](./templates/release.yml) to your repository.

## Differences from release-plz

| Feature | release-plz | moon-release |
|---------|-------------|--------------|
| Platform | GitHub, GitLab, Gitea | GitHub only |
| CHANGELOG | Auto-generated with git-cliff | None (use GitHub Release instead) |
| Dependency Update | `cargo update` | None (MoonBit uses minimal version selection) |
| API Compatibility Check | `cargo-semver-checks` | Built-in (uses moon doc) |
| Config Format | TOML | JSON |
| Registry | crates.io | mooncakes.io |

See [DESIGN_DECISIONS.md](./docs/DESIGN_DECISIONS.md) for details.

## License

MIT
