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

        it "焙煎度の傾向が出せない以上、おすすめが安定しているとは表示しないこと" do
          create(:taste_profile, user: user)
          get preferences_path

          expect(response.body).to include(
            I18n.t("services.recommended_roast.notice.hypothesis")
          )
          expect(response.body).not_to include("安定しています")
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
