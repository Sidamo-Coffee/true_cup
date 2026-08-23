require 'rails_helper'

RSpec.describe "TrialDiagnoses", type: :request do
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

  # 暗号化 Cookie は Rack::Test の cookie jar からは平文で読めないため、
  # 直近のリクエストの鍵で復号する。
  def decrypted_trial_answers
    ActionDispatch::Cookies::CookieJar.build(request, cookies.to_hash).encrypted[:trial_answers]
  end

  def set_cookie_header
    Array(response.headers["set-cookie"] || response.headers["Set-Cookie"]).join("\n")
  end

  describe "GET /trial_diagnosis" do
    it "未ログインでも診断ページが表示されること" do
      get trial_diagnosis_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("コーヒー味覚診断")
    end
  end

  describe "POST /trial_diagnosis" do
    context "全ての質問に回答した場合" do
      it "回答が暗号化Cookieに保存されること" do
        post trial_diagnosis_path, params: { answers: valid_answers }

        expect(JSON.parse(decrypted_trial_answers)).to eq(valid_answers.stringify_keys)
      end

      it "Cookieの有効期限が1時間であること" do
        post trial_diagnosis_path, params: { answers: valid_answers }

        expires = set_cookie_header[/trial_answers=[^;]+;[^\n]*?expires=([^;]+)/i, 1]
        expect(expires).to be_present
        expect(Time.parse(expires)).to be_within(5.minutes).of(1.hour.from_now)
      end

      it "回答に応じた試し診断の結果ページにリダイレクトされること" do
        post trial_diagnosis_path, params: { answers: valid_answers }

        expect(response).to redirect_to(trial_result_path(type: "medium_dark"))
      end

      it "未ログインのためTasteProfileは作られないこと" do
        expect {
          post trial_diagnosis_path, params: { answers: valid_answers }
        }.not_to change(TasteProfile, :count)
      end
    end

    context "未回答の質問がある場合" do
      it "422になり、診断ページが再表示されること" do
        post trial_diagnosis_path, params: { answers: valid_answers.except(:dislike) }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("コーヒー味覚診断")
      end

      it "Cookieが書かれないこと" do
        post trial_diagnosis_path, params: { answers: valid_answers.except(:dislike) }

        expect(cookies[:trial_answers]).to be_blank
      end
    end
  end
end
