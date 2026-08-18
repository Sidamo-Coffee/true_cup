require 'rails_helper'

RSpec.describe DiagnosisGap do
  let(:user) { create(:user) }

  def log(roast:, rating: 5, bitterness: 1, acidity: 1)
    create(:coffee_log, user: user, roast_level: roast, overall_rating: rating,
                        bitterness: bitterness, acidity: acidity)
  end

  def call
    described_class.new(
      taste_profile: user.reload.taste_profile,
      preference_liked: PreferenceSummary.new(user, scope: :liked).call
    ).call
  end

  describe "表示できるかどうか" do
    it "診断が無ければ比較できないこと" do
      3.times { log(roast: :dark) }
      expect(call[:available]).to be false
    end

    it "★4以上の記録が閾値に満たなければ比較できないこと" do
      create(:taste_profile, :light_like, user: user)
      2.times { log(roast: :dark, rating: 5) }
      expect(call[:available]).to be false
    end

    it "診断と★4以上の記録が揃えば比較できること" do
      create(:taste_profile, :light_like, user: user)
      3.times { log(roast: :dark, rating: 5) }
      expect(call[:available]).to be true
    end

    it "低評価の記録は比較対象にしないこと" do
      create(:taste_profile, :light_like, user: user)
      10.times { log(roast: :dark, rating: 2) }
      expect(call[:available]).to be false
    end
  end

  describe "焙煎度の比較" do
    before { create(:taste_profile, :light_like, user: user) } # 診断は浅煎りタイプ

    it "診断と実際が異なる場合、そのことが分かること" do
      3.times { log(roast: :dark, rating: 5) }
      result = call

      expect(result[:roast][:diagnosed_key]).to eq "light"
      expect(result[:roast][:actual_key]).to eq "dark"
      expect(result[:roast][:match]).to be false
    end

    it "診断と実際が一致する場合、そのことが分かること" do
      3.times { log(roast: :light, rating: 5) }
      result = call

      expect(result[:roast][:actual_key]).to eq "light"
      expect(result[:roast][:match]).to be true
    end

    it "焙煎度が不明な記録しかなければ、焙煎度は比較しないこと" do
      3.times { log(roast: :unknown, rating: 5) }
      expect(call[:roast]).to be_nil
    end

    it "おすすめが示す焙煎度と一致すること" do
      # 画面間で矛盾しないよう、おすすめと同じ値を使う
      3.times { log(roast: :dark, rating: 5) }
      liked = PreferenceSummary.new(user, scope: :liked).call
      recommended = RecommendedRoast.new(
        preference_liked: liked,
        preference_all: PreferenceSummary.new(user, scope: :all).call,
        taste_profile: user.reload.taste_profile
      ).call

      expect(call[:roast][:actual_key]).to eq recommended[:roast_key]
    end
  end

  describe "味の比較" do
    it "診断のスコアと★4以上の記録の平均を同じ尺度で並べること" do
      # 診断は「苦味が苦手（2）／酸味が好き（8）」
      create(:taste_profile, user: user,
                             bitterness_score: 2, acidity_score: 8,
                             sweetness_score: 5, body_score: 5)
      # 実際は苦味の強いコーヒーを高く評価している
      3.times { log(roast: :dark, rating: 5, bitterness: 2, acidity: 0) }

      bitterness = call[:axes].find { |a| a[:key] == :bitterness }
      expect(bitterness[:diagnosed]).to eq 2.0
      expect(bitterness[:actual]).to eq 10.0
      expect(bitterness[:diff]).to eq 8.0
      expect(bitterness[:direction]).to eq :higher
    end

    it "実際の方が低ければ direction が lower になること" do
      create(:taste_profile, user: user,
                             bitterness_score: 9, acidity_score: 5,
                             sweetness_score: 5, body_score: 5)
      3.times { log(roast: :light, rating: 5, bitterness: 0, acidity: 1) }

      bitterness = call[:axes].find { |a| a[:key] == :bitterness }
      expect(bitterness[:direction]).to eq :lower
    end

    it "コクと甘みは比較しないこと" do
      # 記録側で収集していないため（コク）、診断側が固定値のため（甘み）
      create(:taste_profile, user: user)
      3.times { log(roast: :dark, rating: 5) }

      expect(call[:axes].map { |a| a[:key] }).to contain_exactly(:bitterness, :acidity)
    end
  end

  describe "総合判定" do
    it "焙煎度も味も近ければ、診断どおりと判定すること" do
      create(:taste_profile, user: user,
                             bitterness_score: 5, acidity_score: 5,
                             sweetness_score: 5, body_score: 5)
      3.times { log(roast: :medium, rating: 5, bitterness: 1, acidity: 1) }

      expect(call[:verdict]).to eq :aligned
    end

    it "焙煎度が違えばズレと判定すること" do
      create(:taste_profile, :light_like, user: user)
      3.times { log(roast: :dark, rating: 5, bitterness: 1, acidity: 1) }

      expect(call[:verdict]).to eq :diverged
    end

    it "焙煎度が同じでも味が大きく違えばズレと判定すること" do
      create(:taste_profile, user: user, preferred_roast: :dark,
                             bitterness_score: 1, acidity_score: 5,
                             sweetness_score: 5, body_score: 5)
      3.times { log(roast: :dark, rating: 5, bitterness: 2, acidity: 1) }

      expect(call[:verdict]).to eq :diverged
    end
  end
end
