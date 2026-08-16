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
      expect(result[:summary_roast_key]).to eq "light"
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
        expect(result[:summary_roast_key]).to eq "light"
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
        expect(result[:summary_roast_key]).to be_nil
      end

      it "信頼度が算出されること" do
        result = described_class.new(user).call
        expect(result[:confidence]).not_to be_nil
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
        expect(result[:summary_roast_key]).to eq "light"
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
    end
  end

  describe "信頼度" do
    it "記録が少なければ low になること" do
      3.times { log(roast: :light, rating: 5) }
      expect(described_class.new(user).call[:confidence]).to eq :low
    end

    it "記録が十分にあれば high になること" do
      15.times { log(roast: :light, rating: 5) }
      expect(described_class.new(user).call[:confidence]).to eq :high
    end

    it "焙煎度が不明な記録も件数に算入すること" do
      15.times { log(roast: :unknown, rating: 5) }
      expect(described_class.new(user).call[:confidence]).to eq :high
    end
  end
end
