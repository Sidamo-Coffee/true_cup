# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Development server
bin/rails server

# Run all tests
bundle exec rspec

# Run a single spec file
bundle exec rspec spec/models/user_spec.rb

# Run a specific example by line number
bundle exec rspec spec/models/user_spec.rb:10

# Lint
bin/rubocop

# Security scan
bin/brakeman --no-pager

# Database
bin/rails db:migrate
bin/rails db:test:prepare
```

## Architecture

### Core Domain

**True Cup** はコーヒーの好みを診断・記録するRails 7アプリ。主なドメインは3つ:

1. **味覚診断** — 5問のアンケートでユーザーのコーヒー嗜好を判定し、4段階のロースト（light / medium / medium_dark / dark）を推薦
2. **コーヒーログ** — 飲んだコーヒーの記録（苦味・酸味・総合評価など）
3. **好み分析** — ログを集計してロースト分布・平均スコアを可視化

### Service Objects (`app/services/`)

ビジネスロジックはサービスクラスに集約されている:

- **`TasteDiagnosisLogic`** — 診断の中核。スコア計算（各5点ベースで加減算）→ロースト判定 → `TasteProfile` への保存を一貫して担う。すべてクラスメソッド。
- **`PreferenceSummary`** — コーヒーログを集計。`:all`（全件）または`:liked`（rating >= 4）のスコープで分析し、グラフ用データと信頼度（low/mid/high）を返す。
- **`RecommendedRoast`** — `liked >= 3件` → `all >= 5件` → `TasteProfile` → 推薦不可、の優先順位でロースト推薦を決定。
- **`RoastGuide`** — 各ロースト種別の購入ガイドキーワードを返すシンプルなデータクラス。

### 試し診断フロー（未ログインユーザー向け）

未ログインユーザーが診断を完了すると結果を**暗号化Cookie（有効期限1時間）**に保存。
その後ユーザー登録すると `Users::RegistrationsController#after_sign_up_path_for` が Cookieを読み取り、診断結果を自動的に `TasteProfile` に反映してマイページへリダイレクトする。

### i18n

アプリはデフォルト日本語。ラベル類はモデルの `*_label` メソッドが `I18n.t` を呼び出す。
診断結果の説明文は `config/locales/ja.yml` の `diagnosis_results.description.*` に定義。

### テスト構成

- `spec/models/` — モデルのバリデーション・関連（shoulda-matchers使用）
- `spec/requests/` — コントローラーのHTTPレスポンスと認証（Devise::Test::IntegrationHelpers使用）
- FactoryBotでテストデータ生成、Database Cleanerでトランザクション管理
- テストの実行順序はランダム（`config.order = :random`）

### CI

GitHub Actionsで `scan_ruby`（Brakeman）→ `lint`（RuboCop）→ `test`（RSpec）を実行。
テスト環境のDB接続は `DATABASE_URL=postgres://postgres:postgres@localhost:5432`。
