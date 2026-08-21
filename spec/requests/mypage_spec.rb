require 'rails_helper'

RSpec.describe "Mypage", type: :request do
  let(:user) { create(:user) }

  describe "GET /mypage" do
    context "ログインしていない場合" do
      it "ログインページにリダイレクトされること" do
        get mypage_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "ログインしている場合" do
      before { sign_in user }

      it "マイページが表示されること" do
        get mypage_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include("マイページ")
      end

      it "挨拶の横にコーヒーアイコンが表示されること" do
        get mypage_path
        expect(response.body).to include('data-illustration="coffee-icon"')
      end

      it "オンボーディングの各ステップに異なるイラストが表示されること" do
        get mypage_path

        # data-step 属性は必ず異なるため、SVGの中身（描画内容）だけを比較する
        drawings = response.body.scan(%r{<svg[^>]*data-illustration="coffee-step"[^>]*>(.*?)</svg>}m).flatten
        expect(drawings.size).to eq(I18n.t("shared.onboarding_modal.steps").size)
        expect(drawings.uniq.size).to eq(drawings.size)
      end


      context "実データを根拠にしている場合" do
        before do
          create(:taste_profile, user: user)
          4.times { create(:coffee_log, :dark_roast, user: user, overall_rating: 5) }
        end

        it "次の段階までの進み具合が表示されること" do
          get mypage_path
          expect(response.body).to include(I18n.t("services.recommended_roast.progress.label.likely"))
          expect(response.body).to include(
            ERB::Util.html_escape(
              I18n.t("services.recommended_roast.progress.remaining.likely", count: 6)
            )
          )
        end

        # #143 確からしさは、それが修飾するおすすめの近くに置く
        it "おすすめの確からしさが、おすすめカードの中に表示されること" do
          get mypage_path

          notice_at   = response.body.index(
            ERB::Util.html_escape(I18n.t("services.recommended_roast.notice.likely", count: 4))
          )
          insights_at = response.body.index(I18n.t("mypage.show.sections.insights"))

          expect(notice_at).to be_present
          expect(notice_at).to be < insights_at
        end
      end


      # #144 件数が同数のとき、片方を「多い」と呼ばない
      context "最も飲んでいる焙煎度が同数の場合" do
        before do
          2.times { create(:coffee_log, :light_roast, user: user, overall_rating: 4) }
          2.times { create(:coffee_log, :dark_roast, user: user, overall_rating: 4) }
        end

        it "同じくらいであることを伝えること" do
          get mypage_path
          expect(response.body).to include(
            ERB::Util.html_escape(
              I18n.t("mypage.show.insights.summary_roast_tied_two", first: "浅煎り", second: "深煎り")
            )
          )
        end

        it "片方を「多い傾向」とは表示しないこと" do
          get mypage_path
          expect(response.body).not_to include(
            ERB::Util.html_escape(I18n.t("mypage.show.insights.summary_roast", roast: "浅煎り"))
          )
          expect(response.body).not_to include(
            ERB::Util.html_escape(I18n.t("mypage.show.insights.summary_roast", roast: "深煎り"))
          )
        end
      end

      # #146 おすすめの評価が同点のとき
      context "評価が同点の焙煎度が2つある場合" do
        before do
          create(:taste_profile, user: user)
          2.times { create(:coffee_log, :light_roast, user: user, overall_rating: 5) }
          2.times { create(:coffee_log, :dark_roast,  user: user, overall_rating: 5) }
        end

        it "2つ併記すること" do
          get mypage_path
          expect(response.body).to include("浅煎り・深煎り")
        end

        it "「評価が最も高い」とは表示しないこと" do
          get mypage_path
          expect(response.body).not_to include(I18n.t("services.recommended_roast.reason.liked"))
          expect(response.body).to include(I18n.t("services.recommended_roast.reason.liked_tied"))
        end

        it "焙煎度ごとの購入ガイドを両方出すこと" do
          get mypage_path
          expect(response.body).to include(ERB::Util.html_escape(RoastGuide.call("light")[:tell]))
          expect(response.body).to include(ERB::Util.html_escape(RoastGuide.call("dark")[:tell]))
        end
      end

      context "評価が同点の焙煎度が3つある場合" do
        before do
          create(:taste_profile, user: user)
          2.times { create(:coffee_log, :light_roast,       user: user, overall_rating: 5) }
          2.times { create(:coffee_log, user: user, roast_level: :medium, overall_rating: 5) }
          2.times { create(:coffee_log, user: user, roast_level: :medium_dark, overall_rating: 5) }
        end

        it "絞り込めていないことを伝えること" do
          get mypage_path
          expect(response.body).to include(
            ERB::Util.html_escape(I18n.t("services.recommended_roast.notice.undecided"))
          )
        end

        it "診断と実際のズレは表示しないこと" do
          # 実際の好みが定まらないのに「実際は◯◯」と言うと、おすすめと食い違う
          get preferences_path
          expect(response.body).not_to include(I18n.t("preferences.show.gap.rediagnose"))
        end
      end

      context "焙煎度が全て不明の記録しかない場合" do
        before { 3.times { create(:coffee_log, user: user, roast_level: :unknown) } }

        it "エラーにならず表示できること" do
          get mypage_path
          expect(response).to have_http_status(:success)
        end

        it "焙煎度を記録するよう促すメッセージが表示されること" do
          get mypage_path
          expect(response.body).to include(I18n.t("mypage.show.insights.unknown_roast_only"))
        end

        it "記録が1件もない旨のメッセージは表示しないこと" do
          get mypage_path
          expect(response.body).not_to include(I18n.t("mypage.show.insights.empty_all"))
        end
      end

      context "味覚診断が未実施の場合" do
        it "診断を促すメッセージが表示されること" do
          get mypage_path
          expect(response.body).to include("味覚診断をはじめる")
        end
      end

      context "味覚診断済みの場合" do
        let(:user) { create(:user, :with_taste_profile) }

        it "診断結果が表示されること" do
          get mypage_path
          expect(response.body).to include("味覚診断結果")
        end
      end

      context "コーヒー記録がある場合" do
        let(:user) { create(:user, :with_coffee_logs) }

        it "最新の記録が表示されること" do
          get mypage_path
          expect(response.body).to include(ERB::Util.html_escape(user.coffee_logs.first.coffee_name))
        end
      end
    end
  end
end
