# Design Decisions

moon-release は release-plz を参考に設計されていますが、MoonBit エコシステムに適合させるためにいくつかの設計上の決定を行っています。このドキュメントでは、release-plz との差異とその理由を説明します。

## release-plz との主な差異

### 1. プラットフォーム対応: GitHub のみ

**release-plz**: GitHub, GitLab, Gitea に対応

**moon-release**: GitHub のみ対応

**理由**:
- MoonBit エコシステムは現時点で GitHub 中心
- mooncakes.io のパッケージホスティングも GitHub 連携が主
- 開発リソースの集中と品質の確保
- 将来的に需要があれば他プラットフォームを追加可能

### 2. CHANGELOG 生成: 機能なし

**release-plz**: git-cliff を使用した CHANGELOG 自動生成

**moon-release**: CHANGELOG 機能なし

**理由**:
- GitHub Release のリリースノートで十分なケースが多い
- リリースノートはコミットサマリーから自動生成される
- CHANGELOG ファイルの管理は手動の方が柔軟
- シンプルさを優先し、必要最小限の機能に絞る

### 3. 依存関係の更新: 機能なし

**release-plz**: `cargo update` による依存関係更新オプション（ロックファイル更新）

**moon-release**: 依存関係更新機能なし

**理由**:
- MoonBit は Go と同様の **minimal version selection** を採用
- `moon.mod.json` に直接バージョンを記載（ロックファイル不要）
- Cargo の `cargo update` に相当する機能が MoonBit のアーキテクチャ上不要

### 4. API 互換性チェック: 自前実装

**release-plz**: `cargo semver-checks` による API 破壊的変更の検出

**moon-release**: `semver_check` オプションで自前の API 互換性チェックを実行

**仕組み**:
- `moon doc` が生成する `package_data.json` を利用
- 最新タグと現在のコードの API を比較
- 以下の破壊的変更を検出:
  - pub 型/関数/メソッドの削除
  - シグネチャの変更
  - 構造体フィールドの削除/変更

**検出可能な変更**:
| 変更の種類 | 検出 | 影響 |
|-----------|------|------|
| pub 関数の削除 | ✅ | Breaking |
| pub 型の削除 | ✅ | Breaking |
| 関数シグネチャの変更 | ✅ | Breaking |
| 構造体フィールドの削除/変更 | ✅ | Breaking |
| pub 関数の追加 | ✅ | Minor |
| pub 型の追加 | ✅ | Minor |

### 5. 設定ファイル形式

**release-plz**: `release-plz.toml` (TOML 形式)

**moon-release**: `release.json` (JSON 形式)

**理由**:
- MoonBit エコシステムは JSON 中心（moon.mod.json, moon.pkg.json）
- 標準ライブラリに JSON パーサーあり
- 追加の依存関係なしで設定を読み込める

### 6. バージョン管理対象

**release-plz**: `Cargo.toml` のバージョン管理

**moon-release**: `moon.mod.json` のバージョン管理

**理由**:
- MoonBit プロジェクトは `moon.mod.json` でバージョンを管理
- Rust プロジェクトとの構造的な違いに対応

### 7. パッケージレジストリ

**release-plz**: crates.io への公開

**moon-release**: mooncakes.io への公開

**理由**:
- MoonBit パッケージは mooncakes.io で管理
- `moon publish` コマンドで公開

## 実装済み機能（release-plz と同等）

以下の機能は release-plz と同等に実装されています：

| 機能 | 説明 |
|------|------|
| Conventional Commits 解析 | feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert |
| Breaking Change 検出 | `!` マーカーと `BREAKING CHANGE:` footer |
| セマンティックバージョニング | major/minor/patch の自動決定 |
| GitHub Release 作成 | タグ + リリースノート |
| PR 自動作成/更新 | release branch → base branch |
| `pr_draft` | ドラフト PR 作成 |
| `pr_labels` | PR ラベル付与 |
| `pr_body` テンプレート | `{{ version }}` プレースホルダー |
| `git_tag_enable` | タグ作成の有効/無効 |
| `git_release_enable` | GitHub Release 作成の有効/無効 |
| `git_release_draft` | ドラフトリリース作成 |
| `git_tag_name` / `git_release_name` | タグ/リリース名テンプレート |
| `git_release_body` | リリースボディテンプレート（`{{ version }}`, `{{ changelog }}`） |
| `allow_dirty` | 未コミット変更の許可 |
| `version_group` | モノレポでのバージョン同期 |
| `custom_major/minor_increment_regex` | カスタムバンプルール |
| モノレポ対応 | 複数パッケージの個別管理 |
| `--dry-run` | プレビューモード |
| `set-version` コマンド | 手動バージョン設定 |
| `registry_check` | 公開前のバージョン確認 |
| `publish_frozen` | `moon publish --frozen` オプション |
| `semver_check` | 自前実装の API 互換性チェック |

## moon-release 独自機能

release-plz にはない moon-release 独自の機能：

| 機能 | 説明 |
|------|------|
| `check` コマンド | 現在の状態と推奨バンプの表示 |
| `init` コマンド | 設定ファイルの初期化 |
| `--prerelease` フラグ | alpha/beta/rc リリース作成 |
| mooncakes.io 統合 | `moon publish` による自動公開 |

## 設計原則

1. **シンプルさ**: 必要最小限の機能に絞り、使いやすさを優先
2. **MoonBit ネイティブ**: MoonBit エコシステムの慣習に従う
3. **GitHub 中心**: 最も使われるプラットフォームに集中
4. **Conventional Commits**: 業界標準のコミット規約を採用
5. **設定より規約**: 合理的なデフォルト値で設定を最小化

## 将来の検討事項

- GitLab / Gitea 対応（需要に応じて）
- CHANGELOG 生成オプション（需要に応じて）
- API 互換性チェック（MoonBit ツールの登場時）
- プラグインシステム（高度なカスタマイズ用）
