class RoastGuide
  GUIDE = {
    "light" => {
      words: %w[ライトロースト シナモンロースト フルーティ 柑橘 爽やか 明るい酸味],
      tell:  "フルーティで、爽やかな酸味のある浅煎りを探しています。"
    },
    "medium" => {
      words: %w[ミディアムロースト ハイロースト バランス ほどよい酸味 ほどよい苦味 飲みやすい],
      tell:  "酸味と苦味のバランスが良い中煎りを探しています。"
    },
    "medium_dark" => {
      words: %w[シティロースト フルシティロースト ほろ苦 香ばしい しっかり コク],
      tell:  "香ばしさとコクがしっかりある中深煎りを探しています。"
    },
    "dark" => {
      words: %w[フレンチロースト イタリアンロースト しっかり苦味 どっしりコク 濃厚 余韻],
      tell:  "しっかり苦みのある深煎りのコーヒーを探しています。"
    }
  }.freeze

  def self.call(roast_key)
    key = roast_key.to_s
    GUIDE[key]
  end
end