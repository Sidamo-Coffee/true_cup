require 'rails_helper'

RSpec.describe RecommendedRoast do
  let(:user) { create(:user) }

  def log(roast:, rating: 4)
    create(:coffee_log, user: user, roast_level: roast, overall_rating: rating)
  end

  def remaining_text(result)
    I18n.t("services.recommended_roast.progress.remaining.#{result[:progress][:stage]}",
           count: result[:progress][:remaining])
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
        expect(result[:roast_keys]).to eq [ "light" ]
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
        expect(result[:roast_keys]).to eq [ "dark" ]
        expect(result[:reason]).to eq I18n.t("services.recommended_roast.reason.all")
      end
    end

    context "記録が少ない場合" do
      before { create(:taste_profile, :dark_like, user: user) }

      it "味覚診断を根拠にすること" do
        result = call(taste_profile: user.reload.taste_profile)
        expect(result[:roast_keys]).to eq [ "dark" ]
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
      expect(result[:roast_keys]).to eq [ "dark" ]
    end

    it "「不明」を推薦しないこと" do
      expect(call(taste_profile: user.reload.taste_profile)[:roast_keys]).not_to include "unknown"
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
        expect(result[:roast_keys]).to eq [ "light" ]
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
        expect(result[:roast_keys]).to eq [ "light" ]
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
        expect(result[:roast_keys]).to eq [ "light" ]
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
        expect(result[:roast_keys]).to eq [ "dark" ]
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
        expect(result[:roast_keys]).to eq [ "light" ]
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
        expect(result[:roast_keys]).to eq [ "dark" ]
      end
    end

    # #146 同点を、説明できない基準で崩さない
    context "評価も件数も同点の焙煎度が2つある場合" do
      before do
        2.times { log(roast: :light, rating: 5) }
        2.times { log(roast: :dark,  rating: 5) }
        create(:taste_profile, user: user)
      end

      it "2つとも推薦すること" do
        result = call(taste_profile: user.reload.taste_profile)

        expect(result[:roast_keys]).to eq [ "light", "dark" ]
        expect(result[:labels]).to eq [ "浅煎り", "深煎り" ]
        expect(result[:tied]).to be true
      end

      it "「最も評価が高い」とは言わないこと" do
        result = call(taste_profile: user.reload.taste_profile)

        expect(result[:reason]).to eq I18n.t("services.recommended_roast.reason.liked_tied")
        expect(result[:reason]).not_to include "最も高い"
        expect(result[:message]).to eq I18n.t("services.recommended_roast.message.liked_tied")
      end

      it "実データを根拠にしていること（診断に戻さない）" do
        expect(call(taste_profile: user.reload.taste_profile)[:confidence]).to eq :likely
      end
    end

    context "同点の焙煎度が3つある場合" do
      before do
        2.times { log(roast: :light,       rating: 5) }
        2.times { log(roast: :medium,      rating: 5) }
        2.times { log(roast: :medium_dark, rating: 5) }
        create(:taste_profile, user: user)
      end

      it "実データを根拠にせず、味覚診断に戻すこと" do
        # 4段階しかないため、3つ並んだ時点で「どれでもよい」と変わらない
        result = call(taste_profile: user.reload.taste_profile)

        expect(result[:confidence]).to eq :hypothesis
        expect(result[:roast_keys]).to eq [ user.reload.taste_profile.preferred_roast.to_s ]
      end

      it "絞り込めていないことを伝えること" do
        result = call(taste_profile: user.reload.taste_profile)

        expect(result[:notice]).to eq I18n.t("services.recommended_roast.notice.undecided")
      end

      it "残り件数を約束しないこと" do
        # 記録を増やしても同点が崩れるとは限らない
        expect(call(taste_profile: user.reload.taste_profile)[:progress]).to be_nil
      end
    end

    context "★4以上は足りないが、全記録では同点が2つある場合" do
      before do
        # ★4以上は2件（閾値3未満）なので all スコープに落ちる
        3.times { log(roast: :light, rating: 3) }
        1.times { log(roast: :light, rating: 5) }
        3.times { log(roast: :dark,  rating: 3) }
        1.times { log(roast: :dark,  rating: 5) }
        create(:taste_profile, user: user)
      end

      it "全記録を根拠に、2つとも推薦すること" do
        result = call(taste_profile: user.reload.taste_profile)

        expect(result[:roast_keys]).to eq [ "light", "dark" ]
        expect(result[:reason]).to eq I18n.t("services.recommended_roast.reason.all_tied")
        expect(result[:message]).to eq I18n.t("services.recommended_roast.message.all_tied")
      end
    end

    context "同点が2つあり、裏付けがまだ少ない場合" do
      before do
        2.times { log(roast: :light, rating: 5) }
        2.times { log(roast: :dark,  rating: 5) }
        create(:taste_profile, user: user)
      end

      it "暫定であることと、絞り込めていないことを両方伝えること" do
        result = call(taste_profile: user.reload.taste_profile)

        expect(result[:confidence]).to eq :likely
        expect(result[:notice]).to eq I18n.t("services.recommended_roast.notice.likely_tied", count: 4)
      end
    end

    context "同点が2つあり、裏付けが十分な場合" do
      before do
        5.times { log(roast: :light, rating: 5) }
        5.times { log(roast: :dark,  rating: 5) }
        create(:taste_profile, user: user)
      end

      it "「傾向は安定しています」とは言い切らないこと" do
        # 絞り込めていないのに安定と言うと、もう決まったように読める
        result = call(taste_profile: user.reload.taste_profile)

        expect(result[:confidence]).to eq :stable
        expect(result[:notice]).to eq I18n.t("services.recommended_roast.notice.stable_tied", count: 10)
        expect(result[:notice]).not_to eq I18n.t("services.recommended_roast.notice.stable", count: 10)
      end
    end

    context "同点が3つあり、いずれも低評価の場合" do
      before do
        2.times { log(roast: :light,       rating: 2) }
        2.times { log(roast: :medium,      rating: 2) }
        2.times { log(roast: :medium_dark, rating: 2) }
        create(:taste_profile, user: user)
      end

      it "「同点で絞れない」ではなく「好みに合うものが無い」と伝えること" do
        # 全部★2で並んでいる状態で「評価を上げると」と促しても行動につながらない
        result = call(taste_profile: user.reload.taste_profile)

        expect(result[:notice]).to eq I18n.t("services.recommended_roast.notice.low_rated")
      end
    end

    context "診断を根拠にする場合" do
      before do
        1.times { log(roast: :light, rating: 5) }
        create(:taste_profile, user: user)
      end

      it "併記にはならないこと" do
        # 診断結果は1つしかない。ここが併記になると hypothesis_tied という
        # 未定義の文言を引いて translation missing が画面に出る
        result = call(taste_profile: user.reload.taste_profile)

        expect(result[:confidence]).to eq :hypothesis
        expect(result[:tied]).to be false
        expect(result[:roast_keys].size).to eq 1
        expect(result[:notice]).not_to include "translation missing"
        expect(result[:reason]).not_to include "translation missing"
      end
    end

    # #146 レビュー指摘: 案内どおり記録しても、同点が続けば実データには切り替わらない
    context "同点がまだ見えていない段階から、記録を足していく場合" do
      before { create(:taste_profile, user: user) }

      it "診断ベースの段階で、件数だけで達成できるとは言い切らないこと" do
        2.times { log(roast: :light, rating: 4) }
        result = call(taste_profile: user.reload.taste_profile)

        expect(result[:progress][:stage]).to eq :hypothesis
        expect(remaining_text(result)).to include "目安"
      end

      it "実データを根拠にした段階でも、件数だけで達成できるとは言い切らないこと" do
        # ここも同じ。★4以上が同点になった瞬間に診断ベースへ戻り、
        # 「あとN件記録すると、傾向が安定します」は実現しない
        3.times { log(roast: :light, rating: 5) }
        result = call(taste_profile: user.reload.taste_profile)

        expect(result[:progress][:stage]).to eq :likely
        expect(remaining_text(result)).to include "目安"
      end

      it "案内どおり記録しても、同点になれば安定に届かないこと" do
        3.times { log(roast: :light,  rating: 5) }
        2.times { log(roast: :medium, rating: 5) }
        before_state = call(taste_profile: user.reload.taste_profile)
        expect(before_state[:confidence]).to eq :likely
        expect(before_state[:tied]).to be false

        # 案内どおり記録を足していくと、三つ巴になって診断ベースまで戻る
        1.times { log(roast: :medium, rating: 5) }
        3.times { log(roast: :dark,   rating: 5) }
        after = call(taste_profile: user.reload.taste_profile)

        expect(after[:confidence]).to eq :hypothesis
        expect(after[:progress]).to be_nil
      end

      it "案内どおり記録して同点になったら、理由が入れ替わること" do
        # ここでバーが消えるのは意図した挙動。件数では進まないため。
        # ただし直前の案内が「あとN件で出せます」と言い切っていると約束破りになる
        log(roast: :light,  rating: 4)
        log(roast: :medium, rating: 4)
        expect(call(taste_profile: user.reload.taste_profile)[:progress]).to be_present

        log(roast: :dark, rating: 4)
        after = call(taste_profile: user.reload.taste_profile)

        expect(after[:progress]).to be_nil
        expect(after[:notice]).to eq I18n.t("services.recommended_roast.notice.undecided")
      end
    end

    context "★4以上だけが3つ同点で、全記録はまだ少ない場合" do
      before do
        # #146 の再現データそのもの。全記録は3件しかなく MIN_ALL(5) に満たない
        1.times { log(roast: :light,  rating: 4) }
        1.times { log(roast: :medium, rating: 4) }
        1.times { log(roast: :dark,   rating: 4) }
        create(:taste_profile, user: user)
      end

      it "絞り込めていないことを伝えること" do
        result = call(taste_profile: user.reload.taste_profile)

        expect(result[:notice]).to eq I18n.t("services.recommended_roast.notice.undecided")
      end

      it "「あとN件でおすすめを出せます」と約束しないこと" do
        # 約束どおり記録を足しても同点が続けば、進捗ごと消えてしまう
        expect(call(taste_profile: user.reload.taste_profile)[:progress]).to be_nil
      end

      it "記録を足しても同点なら、案内が変わらないこと" do
        before_notice = call(taste_profile: user.reload.taste_profile)[:notice]
        1.times { log(roast: :light,  rating: 4) }
        1.times { log(roast: :medium, rating: 4) }
        1.times { log(roast: :dark,   rating: 4) }

        expect(call(taste_profile: user.reload.taste_profile)[:notice]).to eq before_notice
      end
    end

    context "同点の焙煎度が3つあり、診断も無い場合" do
      before do
        2.times { log(roast: :light,       rating: 5) }
        2.times { log(roast: :medium,      rating: 5) }
        2.times { log(roast: :medium_dark, rating: 5) }
      end

      it "推薦しないこと" do
        expect(call(taste_profile: nil)[:available]).to be false
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

  # ここから #122。次の段階までの進み具合を返す
  describe "進捗" do
    before { create(:taste_profile, user: user) }

    context "まだ診断を根拠にしている場合" do
      it "実データに切り替わるまでの残り件数を返すこと" do
        1.times { log(roast: :dark, rating: 5) }
        progress = call(taste_profile: user.reload.taste_profile)[:progress]

        expect(progress[:stage]).to eq :hypothesis
        expect(progress[:current]).to eq 1
        expect(progress[:target]).to eq described_class::MIN_ALL
        expect(progress[:remaining]).to eq described_class::MIN_ALL - 1
      end

      it "記録が1件も無くても、これからの見通しとして返すこと" do
        progress = call(taste_profile: user.reload.taste_profile)[:progress]
        expect(progress[:current]).to eq 0
        expect(progress[:percent]).to eq 0
      end
    end

    # 進捗が後退しないことは、この機能の前提そのもの
    describe "単調に増えること" do
      it "根拠が全記録から★4以上へ切り替わっても後退しないこと" do
        6.times { log(roast: :dark, rating: 3) }
        before_switch = call(taste_profile: user.reload.taste_profile)[:progress]

        3.times { log(roast: :medium, rating: 5) }   # 根拠が★4以上へ切り替わる
        after_switch = call(taste_profile: user.reload.taste_profile)[:progress]

        expect(after_switch[:current]).to be >= before_switch[:current]
        expect(after_switch[:percent]).to be >= before_switch[:percent]
      end

      it "★3ばかりでも記録するたびに進むこと" do
        # 分子に「根拠になった件数」を使うと、★4以上が0件のあいだ動かなくなる
        counts = (1..4).map do |_|
          log(roast: :dark, rating: 3)
          call(taste_profile: user.reload.taste_profile)[:progress][:current]
        end

        expect(counts).to eq [ 1, 2, 3, 4 ]
      end
    end

    context "実データを根拠にしているが安定していない場合" do
      it "安定するまでの残り件数を返すこと" do
        4.times { log(roast: :dark, rating: 5) }
        progress = call(taste_profile: user.reload.taste_profile)[:progress]

        expect(progress[:stage]).to eq :likely
        expect(progress[:current]).to eq 4
        expect(progress[:target]).to eq described_class::STABLE_MIN
        expect(progress[:remaining]).to eq 6
      end
    end

    context "安定している場合" do
      it "残り0件として返すこと" do
        described_class::STABLE_MIN.times { log(roast: :dark, rating: 5) }
        progress = call(taste_profile: user.reload.taste_profile)[:progress]

        expect(progress[:stage]).to eq :stable
        expect(progress[:remaining]).to eq 0
        expect(progress[:percent]).to eq 100
      end

      it "目標を超えても「15 / 10」のような表示にしないこと" do
        (described_class::STABLE_MIN + 5).times { log(roast: :dark, rating: 5) }
        progress = call(taste_profile: user.reload.taste_profile)[:progress]

        expect(progress[:current]).to eq described_class::STABLE_MIN
        expect(progress[:percent]).to eq 100
      end
    end

    # 件数を増やしても段階が進まない状況では、残り件数を約束しない
    context "低評価ばかりで実データを根拠にできない場合" do
      it "進捗を返さないこと" do
        10.times { log(roast: :dark, rating: 2) }
        expect(call(taste_profile: user.reload.taste_profile)[:progress]).to be_nil
      end
    end

    context "焙煎度が不明な記録しかない場合" do
      it "進捗を返さないこと" do
        # 件数ではなく焙煎度の記録が足りていないため、
        # 「あとN件」と言うと誤った期待を持たせる
        5.times { log(roast: :unknown, rating: 5) }
        expect(call(taste_profile: user.reload.taste_profile)[:progress]).to be_nil
      end

      it "★4以上の記録が1件も無い場合も進捗を返さないこと" do
        5.times { log(roast: :unknown, rating: 2) }
        expect(call(taste_profile: user.reload.taste_profile)[:progress]).to be_nil
      end
    end

    context "推薦できない場合" do
      it "進捗を返さないこと" do
        expect(call(taste_profile: nil)[:progress]).to be_nil
      end
    end

    it "割合は0〜100の範囲に収まること" do
      described_class::STABLE_MIN.times { log(roast: :dark, rating: 5) }
      progress = call(taste_profile: user.reload.taste_profile)[:progress]
      expect(progress[:percent]).to be_between(0, 100)
    end
  end
end
