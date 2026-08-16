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
