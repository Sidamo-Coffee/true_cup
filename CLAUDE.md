# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロダクト概要

**True Cup** は「コーヒーは好きだけど自分の好みが分からない」人のためのコーヒー嗜好サポートアプリ。
味覚診断で好みの仮説を立て、飲んだコーヒーを記録するほど傾向が可視化され、おすすめの焙煎度が精緻になっていく**成長型の体験**を提供する。

**想定ユーザーはコーヒー初心者・ライトユーザー**。専門知識のある人向けの本格的な記録アプリではない。
このため実装判断では次の方針を優先する:

- 専門用語を避け、感覚的に答えられる UI にする（診断は選択式、記録は選ぶだけで完了）
- 入力項目を増やさない。記録のハードルを上げる変更は目的に反する
- 説明はイラスト・グラフなど視覚的な手段を優先する

### 機能スコープ

MVP（#63 でリリース済み）: 味覚診断 / コーヒー記録 / 好みの傾向可視化（簡易版）/ おすすめ焙煎度表示（簡易版）/ 診断結果のSNSシェア / 認証。

本リリース以降の構想（未着手）: 好みの傾向可視化とおすすめ表示の高度化、店舗ページ（全ユーザーの記録を集計した味の特徴表示）、コーヒーミニ辞書機能。

## Commands

開発環境は Docker Compose 前提。`web` コンテナ起動時に `bundle install` → `yarn install` → `db:prepare` → `bin/dev`（Procfile.dev: rails server + esbuild watch + Tailwind watch）が走る。

```bash
# 開発サーバー起動（http://localhost:3000）
docker compose up

# 以降のコマンドはコンテナ内で実行する
docker compose exec web bash

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

開発環境のメールは送信されず `/letter_opener` で確認する（パスワードリセットの動作確認時に使う）。

ホスト側のDBポートは既定で 5432。他プロジェクトのDBと衝突する場合は `.env` に `DB_PORT=5434` のように書いて逃がす
（`.env` は gitignore 対象）。アプリ／テストは `database.yml` の `host: db` でコンテナ間接続するため、この値の影響を受けない。

## 技術スタック

| 種類 | 採用技術 |
| --- | --- |
| フロントエンド | Tailwind CSS v4（`@tailwindcss/cli` でビルド）/ Hotwire（Turbo + Stimulus）/ Chartkick + Chart.js |
| サーバーサイド | Ruby on Rails 8.1 |
| データベース | PostgreSQL |
| 認証 | Devise（+ devise-i18n） |
| ページネーション | Kaminari |
| アセット | jsbundling-rails（esbuild）/ cssbundling-rails |
| デプロイ | Render（リポジトリ内に設定ファイルはなく、Render 側で管理） |

CSS は Tailwind ユーティリティをビューに直接書くスタイル。カラーは amber / stone 系のパレットで統一されている。

## Architecture

### Core Domain

主なドメインは3つ:

1. **味覚診断** — 5問のアンケートでユーザーのコーヒー嗜好を判定し、4段階のロースト（light / medium / medium_dark / dark）を推薦
2. **コーヒーログ** — 飲んだコーヒーの記録（苦味・酸味・総合評価など）
3. **好み分析** — ログを集計してロースト分布・平均スコアを可視化

### モデル

- **`User`** — Devise（database_authenticatable / registerable / recoverable / rememberable / validatable）。`name` は必須（50文字以内）。オンボーディング表示済みフラグ `onboarding_completed` を持つ。`has_one :taste_profile` / `has_many :coffee_logs`（いずれも `dependent: :destroy`）。
- **`TasteProfile`** — 診断結果。`user_id` に**ユニークインデックス**があり1ユーザー1件（再診断は更新）。`taste_type` と `preferred_roast` が enum、4つのスコア（bitterness / acidity / sweetness / body）は 0..10。
- **`CoffeeLog`** — 記録本体。必須は `drank_on` / `place` / `roast_level` / `bitterness` / `acidity` / `overall_rating` のみで、`coffee_name`・`cafe_name`・`sweetness`・`body`・`memo` は任意（初心者が書けない項目を必須にしない設計）。`bitterness`・`acidity` は 0..2 の3段階、`overall_rating` は 1..5。`place` / `roast_level` / `brew_method` は `_prefix: true` 付きの enum。

enum のラベルは各モデルの `*_label` メソッド（`place_label` など）を通して取得する。`TasteProfile#preferred_roast_label` は `coffee_log.roast_level` の訳語を共用している。

### Service Objects (`app/services/`)

ビジネスロジックはサービスクラスに集約されている:

- **`TasteDiagnosisLogic`** — 診断の中核。スコア計算（各5点ベースで加減算）→ロースト判定 → `TasteProfile` への保存を一貫して担う。すべてクラスメソッド。
- **`PreferenceSummary`** — コーヒーログを集計。`:all`（全件）または`:liked`（rating >= 4）のスコープで分析し、グラフ用データと信頼度（low/mid/high）を返す。
- **`RecommendedRoast`** — `liked >= 3件` → `all >= 5件` → `TasteProfile` → 推薦不可、の優先順位でロースト推薦を決定。
- **`RoastGuide`** — 各ロースト種別の購入ガイドキーワードを返すシンプルなデータクラス。

記録が増えるほど推薦の根拠が診断結果から実データへ移る、という「成長型体験」がこの優先順位で表現されている。ここを変更するときはプロダクトの中心的な価値に触れる点に注意する。

### 主要な画面と経路

`/`（TOP）/ `/taste_diagnosis/new`（診断）/ `/taste_profile`（診断結果）/ `/coffee_logs`（記録CRUD・検索・ページネーション）/ `/preferences`（好みの傾向）/ `/mypage`（ハブ）/ `/terms`・`/privacy`。
未ログイン向けに `/trial_diagnosis` と `/trial_results/:type` がある。

### 試し診断フロー（未ログインユーザー向け）

未ログインユーザーが診断を完了すると結果を**暗号化Cookie（有効期限1時間）**に保存。
その後ユーザー登録すると `Users::RegistrationsController#after_sign_up_path_for` が Cookieを読み取り、診断結果を自動的に `TasteProfile` に反映してマイページへリダイレクトする。

集客導線として診断結果のSNS（X）シェアを想定しており、診断結果ページは OGP/Twitterカードの meta に対応している（ロースト別の OGP 画像は `public/ogp/*.png`）。

### i18n

アプリはデフォルト日本語。ラベル類はモデルの `*_label` メソッドが `I18n.t` を呼び出す。
診断結果の説明文は `config/locales/ja.yml` の `diagnosis_results.description.*` に定義。
**ビューに日本語を直接書かず、必ず `config/locales/ja.yml` に追加して `t` 経由で参照する。**

### テスト構成

テストは RSpec のみ。`rails new` 生成の Minitest（`test/`）は #105 で削除済みで、システムテストは存在しない。

- `spec/models/` — モデルのバリデーション・関連（shoulda-matchers使用）
- `spec/requests/` — コントローラーのHTTPレスポンスと認証（Devise::Test::IntegrationHelpers使用）
- `spec/views/` — `public/` 配下の静的エラーページなど、リクエストを経由しない検証
- FactoryBotでテストデータ生成、Database Cleanerでトランザクション管理
- テストの実行順序はランダム（`config.order = :random`）

ビューの検証で `coffee_name` など Faker 由来の文字列と本文を突き合わせるときは、
`'` を含む値が HTML エスケープされるため `ERB::Util.html_escape` を通して比較する。

`spec/rails_helper.rb` の冒頭で `Rails.application.reload_routes_unless_loaded` を呼んでいる。
Rails 8.1 はルーティングを遅延読み込みするため、`routes.rb` の `devise_for :users` が評価される
までは `Devise.mappings` が空で、HTTPリクエストより先に `sign_in` を呼ぶ spec が
`Could not find a valid mapping for #<User ...>` で落ちる。これを防ぐためのもので、消してはいけない。

### CI

GitHub Actionsで `scan_ruby`（Brakeman）/ `lint`（RuboCop）/ `test`（RSpec）の3ジョブを**並列**実行する（`needs:` による依存はない）。
テスト環境のDB接続は `DATABASE_URL=postgres://postgres:postgres@localhost:5432`。

`test` ジョブは RSpec を実行する前に **Node のセットアップ・`yarn install`・アセットビルドを明示的に行う**。
`app/assets/builds/` は gitignore されており、`bundle exec rspec` は Rake を経由しないため
`test:prepare` フック（jsbundling / cssbundling の `javascript:build` / `css:build`）が走らない。
これが無いとレイアウトを描画する spec が `AssetNotFound` で失敗する。

`bin/brakeman` からは `--ensure-latest` を外している（#99）。付いているとバージョン不一致だけで
スキャンを実行せず失敗し、Brakeman が新版を出すたびに CI が落ちるため。
Rails 7.2 の EOL 警告は #100 の Rails 8.1 アップグレードで解消したため、`config/brakeman.ignore` は削除済み。

## 開発フロー

GitHub の Issue ベースで開発している（リポジトリ: `Sidamo-Coffee/true_cup`）。

1. Issue を立てる
2. `<issue番号>_<内容>` の形式でブランチを切る（例: `09_coffee_logs`、`95_coffee_illustrations`）
3. 実装してコミット（メッセージは `add:` / `fix:` / `feat:` などの接頭辞 + 日本語）
4. PR を作成しタイトルに Issue 番号を含める
5. **作成した PR をサブエージェントにレビューさせる**（下記）
6. CI 通過後にマージ（マージはユーザーが行う）

Dependabot の PR が定期的に上がるため、依存更新のコミットが履歴に混ざる。

### PR 作成後のレビュー

**PR を作成したら、シニアエンジニア相当のサブエージェントにレビューさせること。**
自分が書いたコードと PR 説明を自分で見直すだけでは見落としが出るため。

Agent ツール（`general-purpose`）にシニアエンジニアとして振る舞うよう指示し、
PR 番号を渡して差分と本文を確認させる。レビューさせる観点:

- **公開すべきでない情報が PR 本文・差分に含まれていないか**
  （認証情報、トークン、個人情報など。過去に開発用アカウントのパスワードを
  PR 本文に書いてしまい、マージ後に指摘を受けた実績がある）
- PR 説明の記述が実際の変更と食い違っていないか（件数・バージョン・挙動の説明など）
- 変更範囲が Issue のスコープを超えていないか、逆に必要な変更が漏れていないか
- テストが変更した挙動を実際に検証しているか

指摘は鵜呑みにせず妥当性を判断し、取り込まなかったものは理由とともにユーザーへ伝える。
