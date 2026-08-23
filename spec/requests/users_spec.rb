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

  # 未ログインの試し診断 → 暗号化Cookie → 登録時に TasteProfile へ反映、という集客導線（#151）。
  # 壊れても新規ユーザーだけが診断結果を失うため、既存ユーザーの動作確認では気づけない。
  describe "試し診断の結果の引き継ぎ" do
    # 深煎り寄りになる回答（taste_diagnoses_spec と同じ組み合わせ）
    let(:valid_answers) do
      {
        chocolate: "dark_chocolate",
        cake: "mont_blanc",
        dressing: "japanese_dressing",
        amount: "little",
        dislike: "too_sour"
      }
    end

    let(:registration_params) do
      {
        user: {
          name: "テストユーザー",
          email: "trial@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    # 壊れたCookieは正規の経路では作れないため、暗号化だけ本物と同じ方法で行って直接置く
    def set_encrypted_trial_cookie(raw_value)
      get root_path
      jar = ActionDispatch::Cookies::CookieJar.build(request, {})
      jar.encrypted[:trial_answers] = raw_value
      cookies[:trial_answers] = jar[:trial_answers]
    end

    context "試し診断を終えてから登録した場合" do
      before { post trial_diagnosis_path, params: { answers: valid_answers } }

      it "診断結果がTasteProfileに引き継がれること" do
        expect {
          post user_registration_path, params: registration_params
        }.to change(TasteProfile, :count).by(1)

        profile = User.find_by(email: "trial@example.com").taste_profile
        expect(profile.preferred_roast).to eq("medium_dark")
        expect(profile.bitterness_score).to eq(10)
        expect(profile.acidity_score).to eq(5)
      end

      it "マイページにリダイレクトされること" do
        post user_registration_path, params: registration_params
        expect(response).to redirect_to(mypage_path)
      end

      it "引き継いだCookieが削除されること" do
        post user_registration_path, params: registration_params
        expect(cookies[:trial_answers]).to be_blank
      end
    end

    # 引き継げなかったのだから、診断済みを前提とするマイページではなく診断ページへ送る
    shared_examples "診断ページへ送られる" do
      it "TasteProfileが作られないこと" do
        expect {
          post user_registration_path, params: registration_params
        }.not_to change(TasteProfile, :count)
      end

      it "診断ページにリダイレクトされること" do
        post user_registration_path, params: registration_params
        expect(response).to redirect_to(new_taste_diagnosis_path)
      end

      it "ユーザー自体は作られること" do
        expect {
          post user_registration_path, params: registration_params
        }.to change(User, :count).by(1)
      end

      it "Cookieが削除されること" do
        post user_registration_path, params: registration_params
        expect(cookies[:trial_answers]).to be_blank
      end
    end

    context "Cookieが壊れている場合" do
      context "JSONとして壊れている場合" do
        before { set_encrypted_trial_cookie("{壊れたJSON") }
        include_examples "診断ページへ送られる"
      end

      context "必須の回答が欠けている場合" do
        before { set_encrypted_trial_cookie(valid_answers.except(:dislike).to_json) }
        include_examples "診断ページへ送られる"
      end

      context "JSONだがオブジェクトではない場合" do
        before { set_encrypted_trial_cookie("[1, 2, 3]") }
        include_examples "診断ページへ送られる"
      end
    end

    context "診断結果の保存に失敗した場合" do
      before do
        post trial_diagnosis_path, params: { answers: valid_answers }
        allow(TasteDiagnosisLogic).to receive(:apply_result_to_user!)
          .and_raise(ActiveRecord::RecordInvalid.new(TasteProfile.new))
      end

      it "例外が外に出ず、診断ページにリダイレクトされること" do
        post user_registration_path, params: registration_params
        expect(response).to redirect_to(new_taste_diagnosis_path)
      end

      it "ユーザー自体は作られること" do
        expect {
          post user_registration_path, params: registration_params
        }.to change(User, :count).by(1)
      end
    end

    context "試し診断をしていない場合" do
      it "診断ページにリダイレクトされること" do
        post user_registration_path, params: registration_params
        expect(response).to redirect_to(new_taste_diagnosis_path)
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

  # confirm_deletion の保護のために authenticate_scope! を再宣言しており、
  # 同名コールバックの再宣言は Devise 既定の条件を置き換える。
  # edit / update の保護が落ちていないことをここで担保する。
  describe "アカウント編集" do
    let(:user) { create(:user) }

    describe "GET /users/edit" do
      context "ログインしていない場合" do
        it "ログインページにリダイレクトされること" do
          get edit_user_registration_path
          expect(response).to redirect_to(new_user_session_path)
        end
      end

      context "ログインしている場合" do
        before { sign_in user }

        it "編集ページが表示されること" do
          get edit_user_registration_path
          expect(response).to have_http_status(:success)
        end
      end
    end

    describe "PATCH /users" do
      context "ログインしていない場合" do
        it "ログインページにリダイレクトされること" do
          patch user_registration_path, params: { user: { name: "改名" } }
          expect(response).to redirect_to(new_user_session_path)
        end
      end
    end
  end

  describe "アカウント削除" do
    let(:user) { create(:user) }

    describe "GET /users/confirm_deletion" do
      context "ログインしていない場合" do
        it "ログインページにリダイレクトされること" do
          get confirm_deletion_user_registration_path
          expect(response).to redirect_to(new_user_session_path)
        end
      end

      context "ログインしている場合" do
        before { sign_in user }

        it "削除確認ページが表示されること" do
          get confirm_deletion_user_registration_path
          expect(response).to have_http_status(:success)
        end
      end
    end

    describe "DELETE /users" do
      context "ログインしていない場合" do
        it "ログインページにリダイレクトされること" do
          delete user_registration_path
          expect(response).to redirect_to(new_user_session_path)
        end
      end

      context "ログインしている場合" do
        before { sign_in user }

        context "正しいパスワードを入力した場合" do
          it "ユーザーが削除されること" do
            expect {
              delete user_registration_path, params: { current_password: "password123" }
            }.to change(User, :count).by(-1)
          end

          it "トップページにリダイレクトされること" do
            delete user_registration_path, params: { current_password: "password123" }
            expect(response).to redirect_to(root_path)
          end

          context "コーヒー記録や診断結果がある場合" do
            let(:user) { create(:user, :with_taste_profile, :with_coffee_logs) }

            it "関連データも削除されること" do
              user_id = user.id
              delete user_registration_path, params: { current_password: "password123" }
              expect(CoffeeLog.where(user_id: user_id)).to be_empty
              expect(TasteProfile.where(user_id: user_id)).to be_empty
            end
          end
        end

        context "誤ったパスワードを入力した場合" do
          it "ユーザーが削除されないこと" do
            expect {
              delete user_registration_path, params: { current_password: "wrongpassword" }
            }.not_to change(User, :count)
          end

          it "削除確認ページにリダイレクトされること" do
            delete user_registration_path, params: { current_password: "wrongpassword" }
            expect(response).to redirect_to(confirm_deletion_user_registration_path)
          end
        end
      end
    end
  end
end
