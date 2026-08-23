#!/usr/bin/env bash
# Render のビルドコマンド（render.yaml の buildCommand から呼ばれる）。
# 途中で失敗したら止める。ここを抜けると壊れたリビジョンがデプロイされる。
set -o errexit

bundle install

# esbuild と Tailwind CLI は devDependencies にある。Render が NODE_ENV=production を入れるのは
# Node ランタイムだけなので Ruby ランタイムでは効かないが、入った場合に
# assets:precompile が落ちるのを防ぐ保険として --production=false を付けておく。
yarn install --frozen-lockfile --production=false

# jsbundling-rails / cssbundling-rails が assets:precompile に
# javascript:build / css:build を差し込むため、yarn build は個別に呼ばない。
bundle exec rails assets:precompile
bundle exec rails assets:clean

# 無料プランでは pre-deploy コマンドを使えないため、ここで migrate する。
bundle exec rails db:migrate
