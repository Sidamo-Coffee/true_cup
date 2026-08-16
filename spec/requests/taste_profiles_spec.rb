require 'rails_helper'

RSpec.describe "TasteProfiles", type: :request do
  describe "GET /taste_profile" do
    context "ログインしていない場合" do
      it "ログインページにリダイレクトされること" do
        get taste_profile_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "診断済みの場合" do
      let(:user) { create(:user, :with_taste_profile) }

      before { sign_in user }

      it "診断結果ページが表示されること" do
        get taste_profile_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include(I18n.t("taste_profiles.show.heading"))
      end

      it "診断結果の焙煎度に対応したイラストが表示されること" do
        get taste_profile_path
        expect(response.body).to include('data-illustration="coffee-roast"')
        expect(response.body).to include('data-roast="medium"')
      end
    end

    context "浅煎りタイプと診断された場合" do
      let(:user) { create(:user) }

      before do
        create(:taste_profile, :light_like, user: user)
        sign_in user
      end

      it "浅煎り用のイラストが表示されること" do
        get taste_profile_path
        expect(response.body).to include('data-roast="light"')
      end
    end
  end
end
