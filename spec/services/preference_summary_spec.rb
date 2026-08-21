require 'rails_helper'

RSpec.describe PreferenceSummary do
  let(:user) { create(:user) }

  # 焙煎度が既知の記録を作る
  def log(roast:, rating: 4, bitterness: 1, acidity: 1, drank_on: Date.current)
    create(:coffee_log, user: user, roast_level: roast, overall_rating: rating,
                        bitterness: bitterness, acidity: acidity, drank_on: drank_on)
  end

  describe "記録が1件もない場合" do
    it "集計不可を返すこと" do
      result = described_class.new(user).call
      expect(result[:available]).to be false
      expect(result[:logs_count]).to eq 0
    end
  end

  describe "焙煎度が既知の記録がある場合" do
    before do
      3.times { log(roast: :light, rating: 5, acidity: 2, bitterness: 0) }
      1.times { log(roast: :dark,  rating: 2, acidity: 0, bitterness: 2) }
    end

    it "最も件数の多い焙煎度をサマリーとすること" do
      result = described_class.new(user).call
      expect(result[:summary_roast_keys]).to eq [ "light" ]
    end

    it "焙煎度の円グラフに全ての焙煎度が含まれること" do
      result = described_class.new(user).call
      expect(result[:roast_pie].values.sum).to eq 4
    end

    it "味の平均を 0..10 スケールで返すこと" do
      result = described_class.new(user).call
      # acidity: (2,2,2,0) の平均 1.5 → 7.5 ／ bitterness: (0,0,0,2) の平均 0.5 → 2.5
      expect(result[:taste_bar]["酸味"]).to eq 7.5
      expect(result[:taste_bar]["苦味"]).to eq 2.5
    end

    context "scope が :liked の場合" do
      it "★4以上の記録だけを集計すること" do
        result = described_class.new(user, scope: :liked).call
        expect(result[:logs_count]).to eq 3
        expect(result[:summary_roast_keys]).to eq [ "light" ]
      end
    end
  end

  # ここから #116 で修正する挙動
  describe "焙煎度が不明の記録の扱い" do
    context "全ての記録が焙煎度不明の場合" do
      before { 10.times { log(roast: :unknown, rating: 5, acidity: 2, bitterness: 0) } }

      it "記録があるものとして扱うこと" do
        result = described_class.new(user).call
        expect(result[:available]).to be true
        expect(result[:logs_count]).to eq 10
      end

      it "味の傾向は集計できること" do
        result = described_class.new(user).call
        expect(result[:taste_bar]["酸味"]).to eq 10.0
        expect(result[:taste_bar]["苦味"]).to eq 0.0
      end

      it "焙煎度の傾向は算出できないこと" do
        result = described_class.new(user).call
        expect(result[:roast_available]).to be false
        expect(result[:roast_logs_count]).to eq 0
        expect(result[:summary_roast_keys]).to eq []
      end
    end

    context "焙煎度が既知の記録と不明の記録が混在する場合" do
      before do
        3.times { log(roast: :light, rating: 5, acidity: 2, bitterness: 0) }
        2.times { log(roast: :unknown, rating: 5, acidity: 2, bitterness: 0) }
      end

      it "記録件数には不明も算入すること" do
        result = described_class.new(user).call
        expect(result[:logs_count]).to eq 5
      end

      it "味の傾向には不明も算入すること" do
        result = described_class.new(user).call
        # 5件すべて acidity: 2 なので 10.0 になる
        expect(result[:taste_bar]["酸味"]).to eq 10.0
      end

      it "焙煎度の集計からは不明を除外すること" do
        result = described_class.new(user).call
        expect(result[:roast_available]).to be true
        expect(result[:roast_logs_count]).to eq 3
        expect(result[:summary_roast_keys]).to eq [ "light" ]
      end

      it "円グラフに「不明」を含めないこと" do
        result = described_class.new(user).call
        expect(result[:roast_pie].keys).not_to include("不明")
        expect(result[:roast_pie].values.sum).to eq 3
      end

      it "焙煎度が不明な記録の件数を返すこと" do
        result = described_class.new(user).call
        expect(result[:unknown_roast_count]).to eq 2
      end

      it "サマリーの説明文が、焙煎度を記録した件数を指していると分かること" do
        result = described_class.new(user).call
        # 全記録は5件だが、焙煎度の集計対象は3件。「全記録（3件）」では矛盾する
        expect(result[:reason]).to include "焙煎度を記録した3件"
        expect(result[:reason]).not_to include "全記録"
      end
    end
  end

  describe "確からしさ" do
    # #118 で RecommendedRoast へ移した。ここで独立に算出すると
    # おすすめの表示と食い違うため、集計側は持たない
    it "集計結果としては返さないこと" do
      15.times { log(roast: :light, rating: 5) }
      result = described_class.new(user).call

      expect(result).not_to have_key(:confidence)
      expect(result).not_to have_key(:notice)
    end
  end
  # #117 で追加。件数最多の summary_* とは別に、評価が最も高い焙煎度を返す
  describe "評価が最も高い焙煎度" do
    it "件数が多い焙煎度ではなく、平均評価が高い焙煎度を返すこと" do
      6.times { log(roast: :dark,  rating: 2) }
      2.times { log(roast: :light, rating: 5) }
      result = described_class.new(user).call

      expect(result[:summary_roast_keys]).to eq [ "dark" ] # よく飲んでいるのは深煎り
      expect(result[:top_rated_roast_keys]).to eq [ "light" ]  # 評価が高いのは浅煎り
      expect(result[:top_rated_average]).to eq 5.0
    end

    it "記録が1件だけの焙煎度は、2件以上ある焙煎度がある限り選ばないこと" do
      1.times { log(roast: :light, rating: 5) }
      5.times { log(roast: :dark,  rating: 4) }
      expect(described_class.new(user).call[:top_rated_roast_keys]).to eq [ "dark" ]
    end

    # #146 評価も件数も並んだら、そこで打ち切って両方返す
    it "評価も件数も同点なら、片方に絞らないこと" do
      2.times { log(roast: :dark,  rating: 5) }
      2.times { log(roast: :light, rating: 5) }
      result = described_class.new(user).call

      expect(result[:top_rated_roast_keys]).to eq [ "light", "dark" ]
      expect(result[:top_rated_tied]).to be true
    end

    it "記録日が違っても、同点なら片方を代表にしないこと" do
      # 記録日で崩す旧タイブレークは廃止した。同じ日に記録すると決着せず、
      # 最後は enum の定義順という説明できない基準になっていた
      log(roast: :dark,  rating: 5, drank_on: Date.current)
      log(roast: :dark,  rating: 5, drank_on: Date.current)
      log(roast: :light, rating: 5, drank_on: Date.current - 30)
      log(roast: :light, rating: 5, drank_on: Date.current - 30)

      expect(described_class.new(user).call[:top_rated_roast_keys]).to eq [ "light", "dark" ]
    end

    it "同点の並び順が、集計の返り順によらず焙煎度の定義順で決まること" do
      # GROUP BY は順序を保証しない。記録から組み立てると、たまたま定義順で
      # 返るせいで並べ替えを消しても気づけないため、逆順のハッシュを直接渡す
      summary = described_class.new(user)
      avgs   = { "dark" => 5.0, "light" => 5.0 }
      counts = { "dark" => 2, "light" => 2 }

      expect(summary.send(:top_rated_roast_keys, avgs, counts)).to eq [ "light", "dark" ]
    end

    it "同点でなければ絞り込めていると分かること" do
      2.times { log(roast: :dark,  rating: 5) }
      2.times { log(roast: :light, rating: 3) }

      expect(described_class.new(user).call[:top_rated_tied]).to be false
    end

    it "2件以上ある焙煎度が無ければ、全体で評価の高いものを選ぶこと" do
      log(roast: :light, rating: 5)
      log(roast: :dark,  rating: 3)
      expect(described_class.new(user).call[:top_rated_roast_keys]).to eq [ "light" ]
    end

    it "評価が同点なら件数の多い方を選ぶこと" do
      2.times { log(roast: :light, rating: 5) }
      4.times { log(roast: :dark,  rating: 5) }
      expect(described_class.new(user).call[:top_rated_roast_keys]).to eq [ "dark" ]
    end

    it "平均は丸めずに返すこと" do
      # 閾値判定に使うため、丸めると境界の挙動が変わる
      log(roast: :light, rating: 5)
      log(roast: :light, rating: 4)
      log(roast: :light, rating: 4)
      expect(described_class.new(user).call[:top_rated_average]).to be_within(0.0001).of(13.0 / 3)
    end

    it "焙煎度が不明な記録は対象にしないこと" do
      3.times { log(roast: :unknown, rating: 5) }
      2.times { log(roast: :dark,    rating: 3) }
      expect(described_class.new(user).call[:top_rated_roast_keys]).to eq [ "dark" ]
    end
  end

  # #144 件数が同数のときは、片方を「最も」と呼ばない
  describe "最も飲んでいる焙煎度が一つに定まらない場合" do
    it "同数の焙煎度をすべて返すこと" do
      2.times { log(roast: :light, rating: 2) }
      2.times { log(roast: :dark,  rating: 5) }
      1.times { log(roast: :medium_dark, rating: 4) }
      result = described_class.new(user).call

      expect(result[:summary_roast_keys]).to contain_exactly("light", "dark")
      expect(result[:summary_tied]).to be true
    end

    it "同数が3つ以上でもすべて返すこと" do
      %i[light medium dark].each { |r| log(roast: r, rating: 4) }
      result = described_class.new(user).call

      expect(result[:summary_roast_keys].size).to eq 3
      expect(result[:summary_tied]).to be true
    end

    it "一つに定まる場合は同数扱いにしないこと" do
      3.times { log(roast: :dark,  rating: 5) }
      1.times { log(roast: :light, rating: 5) }
      result = described_class.new(user).call

      expect(result[:summary_roast_keys]).to eq [ "dark" ]
      expect(result[:summary_tied]).to be false
      expect(result[:summary_roast]).to eq "深煎り"
    end

    it "記録日が違っても、同数なら片方を代表にしないこと" do
      # 記録日で決める旧タイブレークは廃止した。同じ日に複数杯を記録すると
      # 決着せず、実質 enum の定義順で決まってしまうため（#144）
      log(roast: :light, rating: 4, drank_on: Date.current - 10)
      log(roast: :light, rating: 4, drank_on: Date.current - 10)
      log(roast: :dark,  rating: 4, drank_on: Date.current)
      log(roast: :dark,  rating: 4, drank_on: Date.current)
      result = described_class.new(user).call

      expect(result[:summary_roast_keys]).to eq [ "light", "dark" ]
      expect(result[:summary_tied]).to be true
    end

    it "同数の並び順が焙煎度の定義順で決まること" do
      # GROUP BY は順序を保証しない。見出しの左右が実行のたびに入れ替わらないよう固定する
      log(roast: :dark,  rating: 4)
      log(roast: :light, rating: 4)

      2.times do
        expect(described_class.new(user).call[:summary_roast_labels]).to eq [ "浅煎り", "深煎り" ]
      end
    end

    it "3位と同数の焙煎度をランキングから切り落とさないこと" do
      # 同順位にした以上、「同じ #1 なのに1件だけ載らない」のは説明がつかない
      %i[light medium medium_dark dark].each { |r| log(roast: r, rating: 4) }
      ranking = described_class.new(user).call[:ranking]

      expect(ranking.map { |r| r[:rank] }).to eq [ 1, 1, 1, 1 ]
      expect(ranking.map { |r| r[:label] }).to include "深煎り"
    end

    it "3位が同数なら、4件目も同じ順位で載せること" do
      3.times { log(roast: :dark, rating: 4) }
      2.times { log(roast: :light, rating: 4) }
      1.times { log(roast: :medium, rating: 4) }
      1.times { log(roast: :medium_dark, rating: 4) }
      ranking = described_class.new(user).call[:ranking]

      expect(ranking.map { |r| r[:rank] }).to eq [ 1, 2, 3, 3 ]
    end

    it "4位が同数でなければ、従来どおり3件で打ち切ること" do
      4.times { log(roast: :dark, rating: 4) }
      3.times { log(roast: :light, rating: 4) }
      2.times { log(roast: :medium, rating: 4) }
      1.times { log(roast: :medium_dark, rating: 4) }
      ranking = described_class.new(user).call[:ranking]

      expect(ranking.map { |r| r[:rank] }).to eq [ 1, 2, 3 ]
      expect(ranking.map { |r| r[:label] }).not_to include "中深煎り"
    end

    it "「最も飲まれている焙煎度です」とは説明しないこと" do
      2.times { log(roast: :light, rating: 2) }
      2.times { log(roast: :dark,  rating: 5) }
      result = described_class.new(user).call

      expect(result[:reason]).not_to include "最も飲まれている"
      expect(result[:reason]).to include "4件"
    end

    it "同数でなければ従来どおり「最も飲まれている」と説明すること" do
      3.times { log(roast: :dark,  rating: 5) }
      1.times { log(roast: :light, rating: 5) }
      result = described_class.new(user).call

      expect(result[:reason]).to include "最も飲まれている"
    end

    it "ランキングでは同数の焙煎度を同順位にすること" do
      2.times { log(roast: :light, rating: 2) }
      2.times { log(roast: :dark,  rating: 5) }
      1.times { log(roast: :medium_dark, rating: 4) }
      ranks = described_class.new(user).call[:ranking].map { |r| r[:rank] }

      expect(ranks).to eq [ 1, 1, 3 ]
    end

    it "同数でなければ順位は連番になること" do
      3.times { log(roast: :dark,  rating: 5) }
      2.times { log(roast: :light, rating: 5) }
      1.times { log(roast: :medium, rating: 5) }
      ranks = described_class.new(user).call[:ranking].map { |r| r[:rank] }

      expect(ranks).to eq [ 1, 2, 3 ]
    end
  end
end
