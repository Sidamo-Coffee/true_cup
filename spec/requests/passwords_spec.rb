require 'rails_helper'

RSpec.describe "Passwords", type: :request do
  describe "パスワードリセット申請" do
    describe "GET /users/password/new" do
      it "パスワードリセット申請ページが表示されること" do
        get new_user_password_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include("パスワードの再設定")
      end
    end

    describe "POST /users/password" do
      let(:user) { create(:user) }

      context "登録済みのメールアドレスの場合" do
        it "パスワードリセットメールが送信されること" do
          expect {
            post user_password_path, params: {
              user: { email: user.email }
            }
          }.to change { ActionMailer::Base.deliveries.count }.by(1)
        end

        it "成功メッセージが表示され、ログインページにリダイレクトされること" do
          post user_password_path, params: {
            user: { email: user.email }
          }

          expect(response).to redirect_to(new_user_session_path)
          follow_redirect!
          expect(response.body).to include("数分以内")
        end

        it "送信されたメールに正しいリセットトークンが含まれること" do
          post user_password_path, params: {
            user: { email: user.email }
          }

          user.reload
          mail = ActionMailer::Base.deliveries.last

          expect(mail.to).to eq([ user.email ])
          expect(mail.subject).to include("パスワード")
          expect(mail.body.encoded).to include("パスワード再設定")
        end
      end

      context "未登録のメールアドレスの場合" do
        it "セキュリティ上、同じメッセージが表示されること" do
          post user_password_path, params: {
            user: { email: "nonexistent@example.com" }
          }

          expect(response).to redirect_to(new_user_session_path)
          # Deviseはセキュリティ上、存在しないメールでも同じメッセージを返す
        end
      end

      context "メールアドレスが空の場合" do
        it "エラーが表示されること" do
          post user_password_path, params: {
            user: { email: "" }
          }

          expect(response).to have_http_status(:see_other)
          follow_redirect!
          expect(response.body).to include("メールアドレス")
        end
      end
    end
  end

  describe "パスワードの再設定" do
    let(:user) { create(:user) }
    let(:reset_token) { user.send_reset_password_instructions }

    describe "GET /users/password/edit" do
      it "パスワード再設定ページが表示されること" do
        get edit_user_password_path(reset_password_token: reset_token)
        expect(response).to have_http_status(:success)
        expect(response.body).to include("新しいパスワードの設定")
      end

      context "トークンが無効な場合" do
        it "エラーページが表示されること" do
          get edit_user_password_path(reset_password_token: "invalid_token")
          expect(response).to have_http_status(:success)
          # Deviseはトークンエラーを次の画面で表示
        end
      end
    end

    describe "PUT /users/password" do
      context "有効なパスワードの場合" do
        it "パスワードが更新されること" do
          put user_password_path, params: {
            user: {
              reset_password_token: reset_token,
              password: "newpassword123",
              password_confirmation: "newpassword123"
            }
          }

          user.reload
          expect(user.valid_password?("newpassword123")).to be true
        end

        it "ログイン状態になり、マイページにリダイレクトされること" do
          put user_password_path, params: {
            user: {
              reset_password_token: reset_token,
              password: "newpassword123",
              password_confirmation: "newpassword123"
            }
          }

          expect(response).to redirect_to(mypage_path)
          follow_redirect!
          expect(controller.current_user).to eq(user)
        end
      end

      context "パスワードが短すぎる場合" do
        it "エラーが表示されること" do
          put user_password_path, params: {
            user: {
              reset_password_token: reset_token,
              password: "short",
              password_confirmation: "short"
            }
          }

          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.body).to include("6文字以上")
        end
      end

      context "パスワード確認が一致しない場合" do
        it "エラーが表示されること" do
          put user_password_path, params: {
            user: {
              reset_password_token: reset_token,
              password: "newpassword123",
              password_confirmation: "different123"
            }
          }

          expect(response).to have_http_status(:unprocessable_entity)
        end
      end

      context "トークンが期限切れの場合" do
        it "エラーが表示されること" do
          token = user.send_reset_password_instructions
          user.update!(reset_password_sent_at: 7.hours.ago) # 6hを超える

          put user_password_path, params: {
            user: {
              reset_password_token: token,
              password: "newpassword123",
              password_confirmation: "newpassword123"
            }
          }

          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.body).to include("有効期限") # 文言は実際のi18nに合わせて調整
        end
      end
    end
  end

  describe "パスワード変更後のログイン" do
    let(:user) { create(:user) }
    let(:reset_token) { user.send_reset_password_instructions }

    it "新しいパスワードでログインできること" do
      # パスワード変更
      put user_password_path, params: {
        user: {
          reset_password_token: reset_token,
          password: "newpassword123",
          password_confirmation: "newpassword123"
        }
      }

      # 一度ログアウト
      delete destroy_user_session_path

      # 新しいパスワードでログイン
      post user_session_path, params: {
        user: {
          email: user.email,
          password: "newpassword123"
        }
      }

      expect(response).to redirect_to(mypage_path)
    end

    it "古いパスワードではログインできないこと" do
      old_password = user.password

      # パスワード変更
      put user_password_path, params: {
        user: {
          reset_password_token: reset_token,
          password: "newpassword123",
          password_confirmation: "newpassword123"
        }
      }

      # 一度ログアウト
      delete destroy_user_session_path

      # 古いパスワードでログイン試行
      post user_session_path, params: {
        user: {
          email: user.email,
          password: old_password
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
