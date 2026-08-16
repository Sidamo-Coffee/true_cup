require 'rails_helper'

RSpec.describe "StaticPages", type: :request do
  describe "GET /" do
    it "TOPページが表示されること" do
      get root_path
      expect(response).to have_http_status(:success)
    end

    it "ヒーローイラストが表示されること" do
      get root_path
      expect(response.body).to include('data-illustration="coffee-hero"')
    end

    context "ログイン済みの場合" do
      before { sign_in create(:user) }

      it "マイページにリダイレクトされること" do
        get root_path
        expect(response).to redirect_to(mypage_path)
      end
    end
  end

  describe "GET /terms" do
    it "利用規約が表示されること" do
      get terms_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /privacy" do
    it "プライバシーポリシーが表示されること" do
      get privacy_path
      expect(response).to have_http_status(:success)
    end
  end
end
