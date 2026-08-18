---
name: mobile-check
description: true_cup の画面をスマートフォン幅（390px）で表示確認する手順。ビューやスタイルを変更したら必ずこのスキルを使うこと。スマホ表示を確認したい・レスポンシブが崩れていないか見たい・画面を変更した、といった場面で使う。このアプリは主にスマートフォンから使われるため、モバイル幅での崩れは実使用に直撃する。ブラウザのウィンドウリサイズは効かないので、iframe を使う独自の手順が必要。
---

# スマートフォン幅で表示を確認する

## なぜ必要か

このアプリは**スマートフォンから使われる前提**で、モバイル幅の崩れは実使用に直撃する。

そして **Tailwind のクラスから机上で計算しても崩れは見つけられない**。実際に、
幅の計算上は収まるはずの見出しが、隣の長い説明文に押されて1文字ずつ折り返していた例がある。

```
苦
味    高く評価した記録は、診断より強めでした
```

描画させないと分からない。

## ウィンドウのリサイズは使えない

`mcp__claude-in-chrome__resize_window` は**成功を返すのに実際には効かない**。
呼んだ直後に確認しても `innerWidth` が変わっていない。

```
resize_window(width: 390) → "Successfully resized"
window.innerWidth        → 2560   ← 変わっていない
```

これに気づかず「ユーザーが手動で戻している」と誤解したことがあるので、リサイズ結果を信用しないこと。

（macOS の Chrome 拡張経由で確認。将来直る可能性はあるため、`innerWidth` を実際に読んで
効いているか確かめれば、そのときは iframe を使わずに済む）

## iframe を使う

**iframe 内ではメディアクエリが iframe の幅で評価される。** これを利用すると実機相当の判定ができる。

### 1. タブを用意してページを開く

`tabs_context_mcp` → `tabs_create_mcp`（または既存タブ）→ `navigate` で対象ページへ。

**ログインが必要なページは、ユーザーにログインしてもらう。** パスワードは入力しない。
セッションが切れている場合は、その旨を伝えて依頼する。

### 2. iframe を埋め込む

`javascript_tool` で実行する。`transform: scale()` で拡大しても**メディアクエリには影響しない**ため、
390px のレイアウトのまま見やすく表示できる。

```javascript
document.body.innerHTML = '';
document.body.style.cssText = 'margin:0;background:#334155;';
const f = document.createElement('iframe');
f.src = '<確認したいパス>';
f.width = 390; f.height = 900;
// box-sizing を明示するのが要点。ホストページが border-box を当てていると
// ボーダーが内側に食い込み、ビューポートが 390px にならない（実測 378px）
f.style.cssText = 'box-sizing:content-box;border:6px solid #0f172a;border-radius:12px;transform:scale(1.35);transform-origin:top left;background:#fff;';
document.body.appendChild(f);
await new Promise(r => f.addEventListener('load', r, { once: true }));
JSON.stringify({
  iframeInnerWidth: f.contentWindow.innerWidth,
  mdBreakpointInsideIframe: f.contentWindow.matchMedia('(min-width: 768px)').matches
})
```

確認すべきは2点。どちらか外れていれば以降の確認に意味がない。

- **`iframeInnerWidth` が 390 であること。** ここがずれると、狭い端末で出る崩れを取り逃がす
- **`mdBreakpointInsideIframe` が `false` であること。** `true` ならモバイルレイアウトになっていない

### 3. 目的の箇所までスクロールして撮る

```javascript
const f = document.querySelector('iframe');
const d = f.contentDocument;
const target = [...d.querySelectorAll('h2')].find(h => h.textContent.includes('<見出しの一部>'));
target.scrollIntoView({ block: 'start' });
f.contentWindow.scrollBy(0, -12);   // 見出しが上端に張り付かないよう少し戻す
```

そのうえで `computer` の `screenshot` を `save_to_disk: true` で撮る。
ユーザーに見せる画像はディスクに保存し、返答に添える。

### 4. はみ出しを機械的に点検する

目視だけでは見落とすため、数値でも確かめる。

```javascript
const f = document.querySelector('iframe');
const d = f.contentDocument;
const overflow = [...d.querySelectorAll('main *')]
  .filter(el => el.getBoundingClientRect().width > f.contentWindow.innerWidth + 1)
  .map(el => el.tagName + '.' + (el.className || '').toString().slice(0, 40));
JSON.stringify({
  横スクロール: d.documentElement.scrollWidth > f.contentWindow.innerWidth,
  はみ出し件数: overflow.length,
  はみ出し要素: overflow.slice(0, 5)
})
```

`横スクロール: false` かつ `はみ出し件数: 0` が目標。

### 5. 折り返しを疑う箇所は高さで確かめる

日本語の短いラベルは、隣の要素に押されると**1文字ずつ折り返す**。見た目で気づきにくいので、
要素の高さが1行分かを確認する。

`javascript_tool` は呼び出しごとにスコープが独立するため、毎回 `f` と `d` を取り直す。

```javascript
const f = document.querySelector('iframe');
const d = f.contentDocument;
const labels = [...d.querySelectorAll('p')].filter(p => ['<ラベル1>', '<ラベル2>'].includes(p.textContent.trim()));
JSON.stringify({ 各ラベルの高さ: labels.map(l => Math.round(l.getBoundingClientRect().height)) })
```

`text-sm` なら 20px 前後が1行。倍近い値なら折り返している。

## よくある崩れと対処

| 症状 | 原因 | 対処 |
| --- | --- | --- |
| 短いラベルが1文字ずつ折り返す | `flex` で隣の長い要素に押されている | ラベルに `shrink-0`、狭い幅では `flex-col` で縦に積む |
| 2カラムが潰れる | `grid-cols-2` にブレークポイントが無い | `grid md:grid-cols-2` にする |
| 横スクロールが出る | 固定幅やはみ出す要素 | 上記の点検スクリプトで犯人を特定する |

## 終わったら

作ったタブは `tabs_close_mcp` で閉じる。iframe はページを書き換えるため、
**ユーザーが開いていたタブを流用しない**。必ず自分で作ったタブで行う。
