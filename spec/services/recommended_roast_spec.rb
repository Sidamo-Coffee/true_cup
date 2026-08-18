require 'rails_helper'

RSpec.describe RecommendedRoast do
  let(:user) { create(:user) }

  def log(roast:, rating: 4)
    create(:coffee_log, user: user, roast_level: roast, overall_rating: rating)
  end

  def call(taste_profile: user.taste_profile)
    described_class.new(
      preference_liked: PreferenceSummary.new(user, scope: :liked).call,
      preference_all: PreferenceSummary.new(user, scope: :all).call,
      taste_profile: taste_profile
    ).call
  end

  describe "推薦の根拠の優先順位" do
    context "★4以上が3件以上ある場合" do
      before do
        3.times { log(roast: :light, rating: 5) }
        create(:taste_profile, :dark_like, user: user)
      end

      it "★4以上の記録を根拠にすること" do
        result = call(taste_profile: user.reload.taste_profile)
        expect(result[:roast_key]).to eq "light"
        expect(result[:reason]).to eq I18n.t("services.recommended_roast.reason.liked")
      end
    end

    context "★4以上は少ないが全記録が5件以上ある場合" do
      before do
        5.times { log(roast: :dark, rating: 3) }
        create(:taste_profile, :light_like, user: user)
      end

      it "全記録を根拠にすること" do
        result = call(taste_profile: user.reload.taste_profile)
        expect(result[:roast_key]).to eq "dark"
        expect(result[:reason]).to eq I18n.t("services.recommended_roast.reason.all")
      end
    end

    context "記録が少ない場合" do
      before { create(:taste_profile, :dark_like, user: user) }

      it "味覚診断を根拠にすること" do
        result = call(taste_profile: user.reload.taste_profile)
        expect(result[:roast_key]).to eq "dark"
        expect(result[:reason]).to eq I18n.t("services.recommended_roast.reason.diagnosis")
      end
    end

    context "記録も診断もない場合" do
      it "推薦できないこと" do
        expect(call(taste_profile: nil)[:available]).to be false
      end
    end
  end

  # ここから #116 で修正する挙動
  describe "焙煎度が不明な記録しかない場合" do
    before do
      10.times { log(roast: :unknown, rating: 5) }
      create(:taste_profile, :dark_like, user: user)
    end

    it "焙煎度不明の記録を根拠にせず、味覚診断にフォールバックすること" do
      result = call(taste_profile: user.reload.taste_profile)
      expect(result[:reason]).to eq I18n.t("services.recommended_roast.reason.diagnosis")
      expect(result[:roast_key]).to eq "dark"
    end

    it "「不明」を推薦しないこと" do
      expect(call(taste_profile: user.reload.taste_profile)[:roast_key]).not_to eq "unknown"
    end
  end

  describe "焙煎度が既知の記録が閾値に満たず、不明な記録で嵩増しされる場合" do
    before do
      # 既知は★4以上が2件のみ（MIN_LIKED=3 に届かない）
      2.times { log(roast: :light, rating: 5) }
      # 不明が4件。合計6件だが焙煎度の根拠にはならない
      4.times { log(roast: :unknown, rating: 5) }
      create(:taste_profile, :dark_like, user: user)
    end

    it "不明な記録で閾値を満たしたことにしないこと" do
      result = call(taste_profile: user.reload.taste_profile)
      expect(result[:reason]).to eq I18n.t("services.recommended_roast.reason.diagnosis")
    end
  end

  # ここから #118。信頼度をおすすめの根拠から導き、両者が食い違わないようにする
  describe "おすすめの確からしさ" do
    context "味覚診断を根拠にしている場合" do
      before { create(:taste_profile, :dark_like, user: user) }

      it "仮説として扱うこと" do
        result = call(taste_profile: user.reload.taste_profile)
        expect(result[:confidence]).to eq :hypothesis
        expect(result[:notice]).to include "診断結果からの予想"
      end

      it "記録が焙煎度不明ばかりでも「安定している」と言わないこと" do
        15.times { log(roast: :unknown, rating: 5) }
        result = call(taste_profile: user.reload.taste_profile)
        expect(result[:confidence]).to eq :hypothesis
        expect(result[:notice]).not_to include "安定"
      end
    end

    context "実データを根拠にしているが件数が少ない場合" do
      before do
        3.times { log(roast: :light, rating: 5) }
        create(:taste_profile, :dark_like, user: user)
      end

      it "有力として扱い、暫定であることを伝えること" do
        result = call(taste_profile: user.reload.taste_profile)
        expect(result[:confidence]).to eq :likely
        expect(result[:notice]).to include "記録3件"
        expect(result[:notice]).to include "変わることがあります"
      end

      it "焙煎度不明の記録で件数を水増ししないこと" do
        12.times { log(roast: :unknown, rating: 5) }
        result = call(taste_profile: user.reload.taste_profile)
        expect(result[:confidence]).to eq :likely
        expect(result[:notice]).to include "記録3件"
      end
    end

    context "実データを根拠にしていて件数も十分な場合" do
      before do
        described_class::STABLE_MIN.times { log(roast: :light, rating: 5) }
        create(:taste_profile, :dark_like, user: user)
      end

      it "安定として扱うこと" do
        result = call(taste_profile: user.reload.taste_profile)
        expect(result[:confidence]).to eq :stable
        expect(result[:notice]).to include "安定しています"
      end
    end

    context "推薦できない場合" do
      it "確からしさも返さないこと" do
        result = call(taste_profile: nil)
        expect(result[:confidence]).to be_nil
        expect(result[:notice]).to be_nil
      end
    end

    describe "おすすめの根拠と確からしさが食い違わないこと" do
      # #118 で報告された矛盾の再現。根拠が実データなら「暫定」以上、
      # 根拠が診断なら「安定」とは言わない、という関係が常に成り立つ
      it "実データを根拠にしているとき、仮説とは言わないこと" do
        5.times { log(roast: :dark, rating: 3) }
        create(:taste_profile, :light_like, user: user)
        result = call(taste_profile: user.reload.taste_profile)

        expect(result[:reason]).to eq I18n.t("services.recommended_roast.reason.all")
        expect(result[:confidence]).not_to eq :hypothesis
      end

      it "診断を根拠にしているとき、安定とは言わないこと" do
        create(:taste_profile, :dark_like, user: user)
        result = call(taste_profile: user.reload.taste_profile)

        expect(result[:reason]).to eq I18n.t("services.recommended_roast.reason.diagnosis")
        expect(result[:confidence]).not_to eq :stable
      end
    end
  end

  # ここから #117。件数ではなく評価にもとづいて焙煎度を選ぶ
  describe "評価にもとづく選定" do
    context "よく飲んでいるが低評価の焙煎度がある場合" do
      before do
        6.times { log(roast: :dark,  rating: 2) }
        2.times { log(roast: :light, rating: 5) }
        create(:taste_profile, :dark_like, user: user)
      end

      it "件数が多くても低評価の焙煎度は推薦しないこと" do
        result = call(taste_profile: user.reload.taste_profile)
        expect(result[:roast_key]).to eq "light"
      end
    end

    context "★4以上の中に、件数は多いが評価がやや低い焙煎度がある場合" do
      before do
        3.times { log(roast: :light, rating: 5) }
        4.times { log(roast: :dark,  rating: 4) }
        create(:taste_profile, user: user)
      end

      it "件数ではなく評価の高い方を推薦すること" do
        # 優先度1（★4以上）でも件数だけで決まっていた
        result = call(taste_profile: user.reload.taste_profile)
        expect(result[:reason]).to eq I18n.t("services.recommended_roast.reason.liked")
        expect(result[:roast_key]).to eq "light"
      end
    end

    context "低評価の記録しかない場合" do
      before do
        5.times { log(roast: :dark, rating: 1) }
        create(:taste_profile, :light_like, user: user)
      end

      it "実データを根拠にせず、味覚診断に戻すこと" do
        result = call(taste_profile: user.reload.taste_profile)
        expect(result[:reason]).to eq I18n.t("services.recommended_roast.reason.diagnosis")
        expect(result[:roast_key]).to eq "light"
      end

      it "確からしさも仮説として扱うこと" do
        expect(call(taste_profile: user.reload.taste_profile)[:confidence]).to eq :hypothesis
      end
    end

    context "記録が1件だけの焙煎度がある場合" do
      before do
        1.times { log(roast: :light, rating: 5) }
        5.times { log(roast: :dark,  rating: 4) }
        create(:taste_profile, user: user)
      end

      it "1件だけの焙煎度が、複数件ある焙煎度を上回らないこと" do
        # 偶然の1杯が居座らないよう、2件以上ある焙煎度どうしで比べる
        result = call(taste_profile: user.reload.taste_profile)
        expect(result[:roast_key]).to eq "dark"
      end
    end

    context "全ての焙煎度が1件ずつの場合" do
      # 2件以上ある焙煎度が一つも無いため、件数によるふるい分けができない。
      # 焙煎度は unknown を除き4種類しかなく、全記録ベース（5件以上）では
      # 必ずどれかが2件以上になるため、この分岐に入るのは★4以上のときだけ
      before do
        log(roast: :light, rating: 5)
        log(roast: :medium, rating: 4)
        log(roast: :dark, rating: 4)
        create(:taste_profile, user: user)
      end

      it "比較できる焙煎度が無ければ全体で評価の高いものを選ぶこと" do
        result = call(taste_profile: user.reload.taste_profile)
        expect(result[:reason]).to eq I18n.t("services.recommended_roast.reason.liked")
        expect(result[:roast_key]).to eq "light"
      end
    end

    context "評価が同点の焙煎度がある場合" do
      before do
        2.times { log(roast: :light, rating: 5) }
        4.times { log(roast: :dark,  rating: 5) }
        create(:taste_profile, user: user)
      end

      it "件数の多い方を選ぶこと" do
        result = call(taste_profile: user.reload.taste_profile)
        expect(result[:roast_key]).to eq "dark"
      end
    end

    context "記録は十分あるが、どの焙煎度も低評価の場合" do
      before do
        10.times { log(roast: :dark,  rating: 2) }
        1.times  { log(roast: :light, rating: 2) }
        create(:taste_profile, user: user)
      end

      it "「記録するほど近づきます」ではなく、好みが見つかっていない旨を伝えること" do
        # 11件記録しているユーザーに「記録するほど」では、
        # なぜ実データが使われないのか伝わらない
        result = call(taste_profile: user.reload.taste_profile)
        expect(result[:notice]).to eq I18n.t("services.recommended_roast.notice.low_rated")
      end
    end
  end
end
