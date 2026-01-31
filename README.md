# moon-release

MoonBit プロジェクト用のリリース自動化ツール。[release-plz](https://release-plz.dev/) にインスパイアされ、MoonBit エコシステムに最適化されています。

## 特徴

- **Conventional Commits** からセマンティックバージョンを自動決定
- **GitHub Release** の自動作成（タグ + リリースノート）
- **Release PR** の自動作成・更新
- **mooncakes.io** への自動公開
- **API 互換性チェック**（自前実装の semver-checks）
- **モノレポ対応**（version_group による同期）

## インストール

```bash
# ソースからビルド
git clone https://github.com/dijdzv/moon-release
cd moon-release
moon build --target native

# バイナリを PATH に追加
cp target/native/release/build/main/main ~/.local/bin/moon-release
```

## クイックスタート

```bash
# 設定ファイルを初期化
moon-release init

# 現在の状態を確認
moon-release check

# バージョン更新をプレビュー
moon-release update --dry-run

# バージョンを更新
moon-release update

# リリース PR を作成
moon-release release-pr

# リリースを作成（タグ + GitHub Release + publish）
moon-release release
```

## コマンド

### `moon-release check`

現在の状態を確認し、推奨されるバージョンバンプを表示します。

```bash
moon-release check
moon-release check --verbose  # コミット詳細を表示
```

### `moon-release update`

`moon.mod.json` のバージョンを更新します（コミット/プッシュなし）。

```bash
moon-release update              # 自動決定
moon-release update --bump major # 強制的に major バンプ
moon-release update --dry-run    # プレビューのみ
```

### `moon-release release-pr`

リリース用の Pull Request を作成または更新します。

```bash
moon-release release-pr
moon-release release-pr --dry-run
```

### `moon-release release`

Git タグと GitHub Release を作成し、mooncakes.io に公開します。

```bash
moon-release release
moon-release release --prerelease alpha  # プレリリース
moon-release release --dry-run
```

### `moon-release set-version`

バージョンを手動で設定します。

```bash
moon-release set-version 1.0.0
```

### `moon-release init`

設定ファイル `release.json` を作成します。

```bash
moon-release init
moon-release init --force  # 上書き
```

## 設定

`release.json` で動作をカスタマイズできます。

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
  "publish": true,
  "publish_frozen": false,
  "semver_check": true,
  "registry_check": false,
  "allow_dirty": false,
  "custom_major_increment_regex": null,
  "custom_minor_increment_regex": null,
  "packages": []
}
```

### 設定オプション

| オプション | デフォルト | 説明 |
|-----------|-----------|------|
| `pr_title` | `"chore: release v{{ version }}"` | PR タイトルのテンプレート |
| `pr_draft` | `false` | ドラフト PR として作成 |
| `pr_labels` | `[]` | PR に付与するラベル |
| `pr_body` | - | PR 本文のテンプレート |
| `pr_branch_prefix` | `"release/"` | リリースブランチのプレフィックス |
| `base_branch` | `"main"` | PR のベースブランチ |
| `git_tag_enable` | `true` | Git タグを作成するか |
| `git_tag_name` | `"v{{ version }}"` | タグ名のテンプレート |
| `git_release_enable` | `true` | GitHub Release を作成するか |
| `git_release_draft` | `false` | ドラフトリリースとして作成 |
| `git_release_name` | `"Release v{{ version }}"` | リリース名のテンプレート |
| `git_release_body` | `null` | リリース本文のテンプレート（null で自動生成） |
| `publish` | `true` | mooncakes.io に公開するか |
| `publish_frozen` | `false` | `moon publish --frozen` を使用 |
| `semver_check` | `false` | API 互換性チェックを実行 |
| `registry_check` | `false` | 公開前にレジストリのバージョンを確認 |
| `allow_dirty` | `false` | 未コミット変更があっても実行を許可 |
| `custom_major_increment_regex` | `null` | Major バンプのカスタム正規表現 |
| `custom_minor_increment_regex` | `null` | Minor バンプのカスタム正規表現 |

### テンプレート変数

| 変数 | 説明 |
|------|------|
| `{{ version }}` | 新しいバージョン番号 |
| `{{ changelog }}` | 自動生成されたリリースノート（`git_release_body` のみ） |

## Conventional Commits

moon-release は [Conventional Commits](https://www.conventionalcommits.org/) を解析してバージョンを自動決定します。

| コミットタイプ | バンプ | 例 |
|--------------|--------|-----|
| `feat` | Minor | `feat: add new feature` |
| `fix` | Patch | `fix: resolve bug` |
| `feat!` / `fix!` | Major | `feat!: breaking change` |
| `BREAKING CHANGE:` | Major | footer に記載 |

その他のタイプ（`docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`）はバージョンに影響しません。

## API 互換性チェック（semver_check）

`semver_check: true` を設定すると、リリース前に API の破壊的変更を検出します。

```json
{
  "semver_check": true
}
```

### 検出される変更

| 変更 | 影響 |
|------|------|
| pub 型/関数/メソッドの削除 | Breaking (Major) |
| シグネチャの変更 | Breaking (Major) |
| 構造体フィールドの削除/変更 | Breaking (Major) |
| 新しい pub 型/関数の追加 | Addition (Minor) |

### 動作の仕組み

1. 最新タグをチェックアウト → `moon doc` で API を生成
2. 現在のコードに戻る → `moon doc` で API を生成
3. 2つの `package_data.json` を比較
4. 破壊的変更があれば警告を表示

## モノレポ対応

複数パッケージを含むモノレポでは、`packages` で個別に設定できます。

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

同じ `version_group` を持つパッケージは、グループ内で最も大きなバンプタイプに揃えられます。

例: `core` に breaking change、`utils` に feat がある場合、両方とも major バンプになります。

## GitHub Actions

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

      - name: Setup MoonBit
        uses: aspect-build/setup-moonbit@v1

      - name: Install moon-release
        run: |
          # moon-release をインストール

      - name: Create Release PR
        run: moon-release release-pr
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## release-plz との違い

| 機能 | release-plz | moon-release |
|------|-------------|--------------|
| プラットフォーム | GitHub, GitLab, Gitea | GitHub のみ |
| CHANGELOG | git-cliff で自動生成 | なし（GitHub Release で代替） |
| 依存関係更新 | `cargo update` | なし（MoonBit は minimal version selection） |
| API 互換性チェック | `cargo-semver-checks` | 自前実装（moon doc 利用） |
| 設定形式 | TOML | JSON |
| レジストリ | crates.io | mooncakes.io |

詳細は [DESIGN_DECISIONS.md](./DESIGN_DECISIONS.md) を参照してください。

## ライセンス

MIT
