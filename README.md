# daily-price
Amazon.co.jp とヨドバシドットコムの日用品価格を比較する小さな静的サイトです。

GitHub Pages URL: `https://ledsun.github.io/daily-price/`

## 構成

- `products.yaml`
  - 監視対象の商品一覧です。商品名、Amazon URL、ヨドバシ URL を持ちます。
- `prices.json`
  - 直近の取得結果です。サイト表示用の価格データを保持します。
- `bin/add_product.rb`
  - 商品を対話的に追加します。Amazon URL は `dp/:asin` 形式に正規化します。
- `scripts/fetch_prices.rb`
  - Amazon とヨドバシの商品ページを取得し、価格を `prices.json` に保存します。
- `scripts/build_html.rb`
  - `products.yaml` と `prices.json` から `web/index.html` を生成します。
- `web/index.html`
  - GitHub Pages に公開する静的 HTML です。
- `.github/workflows/update.yml`
  - 定期実行で価格取得と HTML 生成を行い、`web/` を GitHub Pages artifact として公開します。

## GitHub Pages

このリポジトリは GitHub Actions で `web/` を Pages artifact として deploy します。

- 公開物: `web/`
- エントリポイント: `web/index.html`
- リポジトリにコミットする更新対象: `prices.json`

GitHub 側の Pages 設定は `GitHub Actions` を公開元にしてください。

## 手動オペレーション

依存を入れます。

```bash
bundle install
```

商品を追加します。

```bash
ruby bin/add_product.rb
```

価格を取得します。

```bash
bundle exec ruby scripts/fetch_prices.rb
```

HTML を生成します。

```bash
bundle exec ruby scripts/build_html.rb
```

ローカルでまとめて更新したい場合は、次の順です。

```bash
bundle exec ruby scripts/fetch_prices.rb
bundle exec ruby scripts/build_html.rb
```

## GitHub Actions の動作

`Update prices` ワークフローは次を実行します。

1. `scripts/fetch_prices.rb` で価格取得
2. `scripts/build_html.rb` で HTML 生成
3. `prices.json` の変更だけを commit / push
4. `web/` を GitHub Pages に deploy

定期実行に加えて、GitHub Actions の `workflow_dispatch` から手動実行もできます。
