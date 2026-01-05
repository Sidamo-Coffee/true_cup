require 'rails_helper'

RSpec.describe "Users", type: :request do
  describe "新規登録" do
    it "新規登録ページが表示されること" do
      get new_user_registration_path
      expect(response).to have_http_status(:success)
    end

    context "有効なパラメータの場合" do
      it "ユーザーが作成され、味覚診断ページにリダイレクトされること" do
        expect {
          post user_registration_path, params: {
            user: {
              name: "テストユーザー",
              email: "test@example.com",
              password: "password123",
              password_confirmation: "password123"
            }
          }
        }.to change(User, :count).by(1)

        expect(response).to redirect_to(new_taste_diagnosis_path)
        follow_redirect!
        expect(response.body).to include("コーヒー味覚診断")
      end
    end

    context "無効なパラメータの場合" do
      it "ユーザーが作成されず、エラーが表示されること" do
        expect {
          post user_registration_path, params: {
            user: {
              name: "",
              email: "invalid",
              password: "pass",
              password_confirmation: "different"
            }
          }
        }.not_to change(User, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "ログイン" do
    let(:user) { create(:user) }

    it "ログインページが表示されること" do
      get new_user_session_path
      expect(response).to have_http_status(:success)
    end

    context "正しい認証情報の場合" do
      it "ログインできてマイページにリダイレクトされること" do
        post user_session_path, params: {
          user: {
            email: user.email,
            password: user.password
          }
        }

        expect(response).to redirect_to(mypage_path)
      end
    end

    context "誤った認証情報の場合" do
      it "ログインできないこと" do
        post user_session_path, params: {
          user: {
            email: user.email,
            password: "wrongpassword"
          }
        }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "ログアウト" do
    let(:user) { create(:user) }

    it "ログアウトできてトップページにリダイレクトされること" do
      sign_in user
      delete destroy_user_session_path

      expect(response).to redirect_to(root_path)
    end
  end
end
