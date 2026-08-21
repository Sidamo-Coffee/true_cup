require 'rails_helper'

RSpec.describe "Preferences", type: :request do
  let(:user) { create(:user) }

  describe "GET /preferences" do
    context "ログインしていない場合" do
      it "ログインページにリダイレクトされること" do
        get preferences_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "ログインしている場合" do
      before { sign_in user }

      it "記録がなくても表示できること" do
        get preferences_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include(I18n.t("preferences.show.empty"))
      end

      context "焙煎度が既知の記録がある場合" do
        before { 3.times { create(:coffee_log, :light_roast, user: user, overall_rating: 5) } }

        it "焙煎度の傾向が表示されること" do
          get preferences_path
          expect(response).to have_http_status(:success)
          expect(response.body).to include(I18n.t("preferences.show.ranking.title"))
        end
      end




      # #143 おすすめに関する表示はマイページに集約する
      context "おすすめの確からしさと進み具合" do
        before do
          create(:taste_profile, user: user)
          4.times { create(:coffee_log, :dark_roast, user: user, overall_rating: 5) }
        end

        it "確からしさを表示しないこと" do
          get preferences_path
          expect(response.body).not_to include(
            ERB::Util.html_escape(I18n.t("services.recommended_roast.notice.likely", count: 4))
          )
        end

        it "進み具合も表示しないこと" do
          # 「あと N 件でおすすめを出せます」もおすすめの話。
          # おすすめ本体が無いページに置くと、直前の見出しの説明に読める
          get preferences_path
          expect(response.body).not_to include(I18n.t("services.recommended_roast.progress.label.likely"))
        end

        it "★4以上タブでも表示しないこと" do
          # 進み具合の分子は全記録ベースで、このタブの「3件」とは意味が違う
          get preferences_path(scope: "liked")
          expect(response.body).not_to include(I18n.t("services.recommended_roast.progress.label.likely"))
        end
      end

      # #144 件数が同数のとき
      context "最も飲んでいる焙煎度が同数の場合" do
        before do
          2.times { create(:coffee_log, :light_roast, user: user, overall_rating: 2) }
          2.times { create(:coffee_log, :dark_roast, user: user, overall_rating: 5) }
        end

        it "片方を「最も飲んでいる」とは表示しないこと" do
          get preferences_path
          expect(response.body).not_to include(
            ERB::Util.html_escape(
              I18n.t("preferences.show.summary.text", roast: "浅煎り",
                     suffix: I18n.t("preferences.show.summary.suffix.all"))
            )
          )
        end

        it "同じくらい飲んでいることを伝えること" do
          # 焙煎度名はランキングにも出るため、見出しの文ごと突き合わせる
          get preferences_path
          expect(response.body).to include(
            ERB::Util.html_escape(
              I18n.t("preferences.show.summary.tied_two", first: "浅煎り", second: "深煎り",
                     suffix: I18n.t("preferences.show.summary.suffix_tied.all"))
            )
          )
        end
      end

      # #120 診断と実際のズレ
      context "診断があり、★4以上の記録が十分にある場合" do
        before do
          create(:taste_profile, :light_like, user: user)  # 診断は浅煎りタイプ
          3.times { create(:coffee_log, :dark_roast, user: user, overall_rating: 5) }
        end

        it "診断と実際のズレが表示されること" do
          get preferences_path
          expect(response.body).to include(I18n.t("preferences.show.gap.title"))
        end

        it "診断と実際の焙煎度が食い違っていることを伝えること" do
          get preferences_path
          expect(response.body).to include(
            ERB::Util.html_escape(
              I18n.t("preferences.show.gap.lead_diverged", diagnosed: "浅煎り", actual: "深煎り")
            )
          )
        end

        it "何件をもとにしているか示すこと" do
          get preferences_path
          expect(response.body).to include(I18n.t("preferences.show.gap.based_on", count: 3))
        end

        it "ズレている場合は再診断への導線を出すこと" do
          get preferences_path
          expect(response.body).to include(I18n.t("preferences.show.gap.rediagnose"))
        end
      end

      # #146 焙煎度が同点で絞り込めない場合
      context "★4以上の記録で、3つの焙煎度が同点の場合" do
        before do
          create(:taste_profile, :light_like, user: user)
          2.times { create(:coffee_log, :light_roast, user: user, overall_rating: 5) }
          2.times { create(:coffee_log, user: user, roast_level: :medium, overall_rating: 5) }
          2.times { create(:coffee_log, :dark_roast,  user: user, overall_rating: 5) }
        end

        it "「診断どおり」とも「実際は◯◯」とも言わないこと" do
          # おすすめは「絞り込めていません」と言っている。ここで一致を主張すると食い違う
          get preferences_path

          expect(response.body).to include(I18n.t("preferences.show.gap.lead_roast_undecided", raise: true))
          expect(response.body).not_to include(
            I18n.t("preferences.show.gap.lead_taste_only_aligned", raise: true)
          )
          expect(response.body).not_to include(
            ERB::Util.html_escape(
              I18n.t("preferences.show.gap.lead_aligned", diagnosed: "浅煎り", actual: "浅煎り")
            )
          )
        end

        it "味の傾向は引き続き並べること" do
          get preferences_path
          expect(response.body).to include(I18n.t("preferences.show.gap.axis.bitterness"))
        end
      end

      context "焙煎度は診断どおりだが、味だけがズレている場合" do
        before do
          create(:taste_profile, user: user, preferred_roast: :dark,
                                 bitterness_score: 1, acidity_score: 5,
                                 sweetness_score: 5, body_score: 5)
          3.times { create(:coffee_log, :dark_roast, user: user, overall_rating: 5) }
        end

        it "「診断ではAでしたが実際もA」という破綻した文を出さないこと" do
          get preferences_path
          expect(response.body).to include(
            ERB::Util.html_escape(
              I18n.t("preferences.show.gap.lead_aligned", diagnosed: "深煎り", actual: "深煎り")
            )
          )
          expect(response.body).not_to include(
            ERB::Util.html_escape(
              I18n.t("preferences.show.gap.lead_diverged", diagnosed: "深煎り", actual: "深煎り")
            )
          )
        end

        it "味のズレは伝わること" do
          get preferences_path
          expect(response.body).to include(I18n.t("preferences.show.gap.direction.higher"))
        end
      end

      context "診断はあるが★4以上の記録が少ない場合" do
        before do
          create(:taste_profile, :light_like, user: user)
          2.times { create(:coffee_log, :dark_roast, user: user, overall_rating: 5) }
        end

        it "ズレは表示しないこと" do
          get preferences_path
          expect(response.body).not_to include(I18n.t("preferences.show.gap.title"))
        end
      end

      context "診断が未実施の場合" do
        before { 5.times { create(:coffee_log, :dark_roast, user: user, overall_rating: 5) } }

        it "ズレは表示しないこと" do
          get preferences_path
          expect(response.body).not_to include(I18n.t("preferences.show.gap.title"))
        end
      end

      context "診断どおりの好みだった場合" do
        before do
          create(:taste_profile, :light_like, user: user)
          3.times { create(:coffee_log, :light_roast, user: user, overall_rating: 5) }
        end

        it "診断どおりであることを肯定的に伝えること" do
          get preferences_path
          expect(response.body).to include(
            ERB::Util.html_escape(
              I18n.t("preferences.show.gap.lead_aligned", diagnosed: "浅煎り", actual: "浅煎り")
            )
          )
        end

        it "再診断への導線は出さないこと" do
          get preferences_path
          expect(response.body).not_to include(I18n.t("preferences.show.gap.rediagnose"))
        end
      end

      context "焙煎度が全て不明の記録しかない場合" do
        before { 3.times { create(:coffee_log, user: user, roast_level: :unknown) } }

        it "エラーにならず表示できること" do
          get preferences_path
          expect(response).to have_http_status(:success)
        end

        it "記録がない旨のメッセージは表示しないこと" do
          get preferences_path
          expect(response.body).not_to include(I18n.t("preferences.show.empty"))
        end

        it "味の傾向は表示されること" do
          get preferences_path
          expect(response.body).to include(I18n.t("preferences.show.charts.taste.title"))
        end

        it "焙煎度を記録するよう促すメッセージが表示されること" do
          get preferences_path
          expect(response.body).to include(I18n.t("preferences.show.charts.roast.unknown_only"))
        end

        it "焙煎度ランキングは表示しないこと" do
          get preferences_path
          expect(response.body).not_to include(I18n.t("preferences.show.ranking.title"))
        end

        it "サマリーの見出しは表示しないこと" do
          # 焙煎度が決まらないため見出しを出せない。空のカードを残さない
          get preferences_path
          expect(response.body).not_to include(I18n.t("preferences.show.summary.suffix.all"))
        end

        it "おすすめの確からしさは表示しないこと" do
          # おすすめ本体はこのページに無い。確からしさだけ置くと、
          # すぐ上の見出しを修飾しているように読める（#143）
          create(:taste_profile, user: user)
          get preferences_path

          expect(response.body).not_to include(
            I18n.t("services.recommended_roast.notice.hypothesis")
          )
        end
      end

      context "焙煎度が既知の記録と不明の記録が混在する場合" do
        before do
          2.times { create(:coffee_log, :light_roast, user: user) }
          3.times { create(:coffee_log, user: user, roast_level: :unknown) }
        end

        it "焙煎度の傾向を表示しつつ、不明な記録の件数も知らせること" do
          get preferences_path
          expect(response.body).to include(I18n.t("preferences.show.ranking.title"))
          expect(response.body).to include(
            I18n.t("preferences.show.charts.roast.unknown_note", count: 3)
          )
        end
      end
    end
  end
end
