# moon-release

Automated release management tool for MoonBit projects. Inspired by [release-plz](https://github.com/release-plz/release-plz), optimized for the MoonBit ecosystem.

## Features

- **Conventional Commits** - Automatically determine semantic version from commits
- **GitHub Release** - Automatic creation of tags and release notes
- **Release PR** - Automatic creation and update of release pull requests
- **mooncakes.io** - Automatic publishing to the MoonBit package registry
- **npm** - Automatic publishing to the npm registry
- **API Compatibility Check** - semver-checks for breaking change detection
- **Monorepo Support** - Version synchronization via version_group

## Installation

### From mooncakes.io (recommended)

```bash
moon install dijdzv/moon-release
```

### Download binary

Download pre-built binaries from [GitHub Releases](https://github.com/dijdzv/moon-release/releases/latest):

```bash
# Linux (x86_64)
curl -fsSL -o moon-release https://github.com/dijdzv/moon-release/releases/latest/download/moon-release-linux-x86_64
chmod +x moon-release

# macOS (Apple Silicon)
curl -fsSL -o moon-release https://github.com/dijdzv/moon-release/releases/latest/download/moon-release-macos-arm64
chmod +x moon-release
```

### Build from source

```bash
git clone https://github.com/dijdzv/moon-release
cd moon-release
moon build --target native --release
cp _build/native/release/build/src/main/main.exe ~/.local/bin/moon-release
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
moon-release update --bump major # Force major bump (changed packages only)
moon-release update --bump-all   # Bump all packages (monorepo)
moon-release update --bump major --bump-all  # Force major bump on all packages
moon-release update --dry-run    # Preview only
moon-release update -o json      # Output in JSON format
```

### `moon-release release-pr`

Create or update a release Pull Request.

```bash
moon-release release-pr
moon-release release-pr --bump major           # Force major bump
moon-release release-pr --bump-all             # Include all packages
moon-release release-pr --bump major --bump-all # Force major on all packages
moon-release release-pr --dry-run
```

### `moon-release release`

Create Git tag and GitHub Release, and publish to mooncakes.io.

```bash
moon-release release
moon-release release --bump major           # Force major bump
moon-release release --bump-all             # Include all packages
moon-release release --bump major --bump-all # Force major on all packages
moon-release release --prerelease alpha     # Prerelease
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
  "moon_publish": true,
  "moon_publish_frozen": false,
  "moon_publish_timeout": 300,
  "npm_publish": false,
  "npm_build_command": null,
  "npm_publish_provenance": true,
  "npm_publish_timeout": 300,
  "semver_check": false,
  "registry_check": false,
  "allow_dirty": false,
  "custom_major_increment_regex": null,
  "custom_minor_increment_regex": null,
  "max_analyze_commits": null,
  "bump_all_packages": false,
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
| `allow_prerelease` | `false` | Allow prerelease versions (e.g., `--prerelease alpha`) |
| `git_tag_enable` | `true` | Whether to create Git tag |
| `git_tag_name` | `"v{{ version }}"` | Tag name template |
| `git_release_enable` | `true` | Whether to create GitHub Release |
| `git_release_draft` | `false` | Create as draft release |
| `git_release_name` | `"Release v{{ version }}"` | Release name template |
| `git_release_body` | `null` | Release body template (null for auto-generate) |
| `git_release_latest` | `true` | Mark GitHub Release as latest |
| `moon_publish` | `true` | Whether to publish to mooncakes.io |
| `moon_publish_frozen` | `false` | Use `moon publish --frozen` |
| `moon_publish_timeout` | `300` | Publish timeout in seconds |
| `npm_publish` | `false` | Whether to publish to npm registry |
| `npm_build_command` | `null` | Custom build command before npm publish (default: `moon build --target js`). Note: split by spaces, paths with spaces are not supported. |
| `npm_publish_provenance` | `true` | Use `--provenance` flag for npm publish. Set to `false` for local or non-GitHub CI publishing. |
| `npm_publish_timeout` | `300` | npm publish timeout in seconds |
| `semver_check` | `false` | Run API compatibility check |
| `registry_check` | `false` | Check registry version before publish |
| `allow_dirty` | `false` | Allow uncommitted changes |
| `custom_major_increment_regex` | `null` | Custom substring pattern for major bump (matched against commit description) |
| `custom_minor_increment_regex` | `null` | Custom substring pattern for minor bump (matched against commit description) |
| `max_analyze_commits` | `null` | Maximum number of commits to analyze |
| `bump_all_packages` | `false` | Bump all packages uniformly in monorepo mode (fixed versioning) |

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
      "moon_publish": true,
      "npm_publish": true,
      "version_group": "main"
    },
    {
      "name": "utils",
      "path": "packages/utils",
      "moon_publish": true,
      "npm_publish": false,
      "version_group": "main"
    },
    {
      "name": "internal",
      "path": "packages/internal",
      "moon_publish": false,
      "npm_publish": false
    }
  ]
}
```

### Versioning Strategies

#### Independent (default)

Only packages with changes are bumped. Each package gets its own bump type based on its commits.

```bash
# Only changed packages are bumped
moon-release update

# Force major bump on changed packages only
moon-release update --bump major
```

#### Fixed (`bump_all_packages` or `--bump-all`)

All packages are bumped uniformly using the highest bump type found across changed packages.

```json
{
  "bump_all_packages": true
}
```

Or use the CLI flag for one-time override:

```bash
# Bump all packages (uses max bump type from changed packages)
moon-release update --bump-all

# Force major bump on ALL packages
moon-release update --bump major --bump-all
```

| Config `bump_all_packages` | CLI | Behavior |
|---|---|---|
| `false` | (none) | Changed packages only, auto bump type |
| `false` | `--bump major` | Changed packages only, forced major |
| `false` | `--bump-all` | All packages, max bump type from changes |
| `false` | `--bump major --bump-all` | All packages, forced major |
| `true` | (none) | All packages, max bump type from changes |
| `true` | `--bump major` | All packages, forced major |

> **Note:** `--bump` controls the bump **type** (major/minor/patch), while `--bump-all` controls the bump **scope** (changed-only vs all packages).

### version_group

Packages with the same `version_group` are aligned to the largest bump type within the group.

Example: If `core` has a breaking change and `utils` has a feat, both will receive a major bump.

## GitHub Actions

### Required Setup

Before using moon-release in GitHub Actions, you need to configure the following:

#### 1. Repository Permissions

Go to **Settings → Actions → General → Workflow permissions**:

- Select **"Read and write permissions"**
- Check **"Allow GitHub Actions to create and approve pull requests"**

> Without these settings, moon-release cannot create release PRs.

#### 2. Workflow File Setup

Create `.github/workflows/release.yml`:

```yaml
name: Release

on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: write
  pull-requests: write

jobs:
  release-pr:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Setup MoonBit
        run: |
          curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash
          echo "$HOME/.moon/bin" >> $GITHUB_PATH

      - name: Download moon-release
        run: |
          curl -fsSL -o moon-release https://github.com/dijdzv/moon-release/releases/latest/download/moon-release-linux-x86_64
          chmod +x moon-release

      - name: Configure Git
        run: |
          git config --global user.name "github-actions[bot]"
          git config --global user.email "github-actions[bot]@users.noreply.github.com"

      - name: Create Release PR
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: ./moon-release release-pr --verbose
```

**Key points:**
- `fetch-depth: 0` - Required to analyze commit history
- Setup MoonBit - Installs MoonBit toolchain via official installer
- Git config - Required for committing version changes
- `GITHUB_TOKEN` - Automatically provided by GitHub Actions

### Publishing to mooncakes.io (Optional)

To automatically publish to mooncakes.io, additional configuration is required.

#### 1. Get mooncakes Token

```bash
# Authenticate locally
moon login

# Check token
cat ~/.moon/credentials.json
# {"token": "xxxxx", "username": "your-username"}
```

#### 2. Configure GitHub Secrets

Go to **Settings → Secrets and variables → Actions → New repository secret**:

| Secret Name | Value |
|-------------|-------|
| `MOONCAKES_TOKEN` | The `token` value from credentials.json |
| `MOONCAKES_USERNAME` | The `username` value from credentials.json |

#### 3. Add to Workflow

Add the release job that runs when a release PR is merged:

```yaml
  release:
    runs-on: ubuntu-latest
    # Run only when release PR is merged
    if: github.event_name == 'push' && startsWith(github.event.head_commit.message, 'chore:') && contains(github.event.head_commit.message, 'release v')
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Setup MoonBit
        run: |
          curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash
          echo "$HOME/.moon/bin" >> $GITHUB_PATH

      - name: Configure mooncakes credentials
        env:
          MOONCAKES_TOKEN: ${{ secrets.MOONCAKES_TOKEN }}
          MOONCAKES_USERNAME: ${{ secrets.MOONCAKES_USERNAME }}
        run: |
          mkdir -p ~/.moon
          jq -n --arg token "$MOONCAKES_TOKEN" --arg username "$MOONCAKES_USERNAME" \
            '{"token": $token, "username": $username}' > ~/.moon/credentials.json

      - name: Download moon-release
        run: |
          curl -fsSL -o moon-release https://github.com/dijdzv/moon-release/releases/latest/download/moon-release-linux-x86_64
          chmod +x moon-release

      - name: Create Release
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: ./moon-release release --verbose
```

> **⚠️ Security Notice**
>
> mooncakes.io does not currently provide limited-scope tokens for CI use.
> The token in `~/.moon/credentials.json` may have full account permissions.
> Use at your own risk with this understanding.

### Publishing to npm (Optional)

moon-release uses **npm Trusted Publishing** (OIDC) for secure, tokenless authentication.

#### 1. Configure Trusted Publishing on npmjs.com

1. Go to [npmjs.com](https://www.npmjs.com/) and log in
2. Navigate to your package → **Settings** → **Configure Trusted Publishing**
3. Add a new trusted publisher:
   - **Repository owner**: Your GitHub username or organization
   - **Repository name**: Your repository name
   - **Workflow filename**: `release.yml` (or your workflow file)
   - **Environment**: (leave empty or set if using environments)

> **💡 Note:** If this is a new package, you need to publish it once manually first:
> ```bash
> npm publish --access public
> ```

#### 2. Update Configuration

Enable npm publishing in `release.json`:

```json
{
  "moon_publish": true,
  "npm_publish": true,
  "npm_build_command": "moon build --target js"
}
```

#### 3. Update Workflow

Add `id-token: write` permission to your workflow:

```yaml
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      id-token: write  # Required for npm Trusted Publishing
    steps:
      # ... other steps ...

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          registry-url: 'https://registry.npmjs.org'

      - name: Create Release
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: ./moon-release release --verbose
```

> **🔒 Security:** Trusted Publishing is more secure than access tokens:
> - No secrets to store or rotate
> - Short-lived tokens generated per-workflow
> - Scoped to specific repository and workflow

#### Execution Order

When `npm_publish` is enabled, moon-release executes in this order:

1. **Build JS target** - Runs `npm_build_command` (default: `moon build --target js`)
2. Create Git tag
3. Create GitHub Release
4. Publish to mooncakes.io (if `moon_publish: true`)
5. Publish to npm

If the JS build fails, no tag or release is created (atomic operation).

### Configuration Summary

| Setting | Required | Where to Configure |
|---------|----------|-------------------|
| Repository write permissions | Yes | Settings → Actions → General |
| Allow PR creation | Yes | Settings → Actions → General |
| `GITHUB_TOKEN` | Yes (auto) | Automatically provided |
| `MOONCAKES_TOKEN` | For mooncakes publish | Settings → Secrets |
| `MOONCAKES_USERNAME` | For mooncakes publish | Settings → Secrets |
| `id-token: write` | For npm publish | Workflow permissions |
| Trusted Publishing | For npm publish | npmjs.com package settings |

### Workflow Template

See [templates/release.yml](./templates/release.yml) for a complete example.

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
