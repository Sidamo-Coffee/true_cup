require 'rails_helper'

RSpec.describe "TasteDiagnoses", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe "GET /taste_diagnosis/new" do
    it "診断ページが表示されること" do
      get new_taste_diagnosis_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("コーヒー味覚診断")
    end
  end

  describe "POST /taste_diagnosis" do
    let(:valid_answers) {
      {
        chocolate: "dark_chocolate",
        cake: "mont_blanc",
        dressing: "japanese_dressing",
        amount: "little",
        dislike: "too_sour"
      }
    }

    context "全ての質問に回答した場合" do
      it "TasteProfileが作成されること" do
        expect {
          post taste_diagnosis_path, params: { answers: valid_answers }
        }.to change(TasteProfile, :count).by(1)
      end

      it "診断結果ページにリダイレクトされること" do
        post taste_diagnosis_path, params: { answers: valid_answers }
        expect(response).to redirect_to(taste_profile_path)
        follow_redirect!
        expect(response.body).to include("あなたのコーヒー味覚診断結果")
      end

      it "適切な焙煎度が判定されること（深煎り寄りの回答）" do
        post taste_diagnosis_path, params: { answers: valid_answers }
        profile = user.reload.taste_profile

        # この回答パターンは深煎り寄りになるはず
        expect(profile.preferred_roast).to be_in([ 'medium_dark', 'dark' ])
        expect(profile.bitterness_score).to be >= 5
      end
    end

    context "未回答の質問がある場合" do
      it "エラーメッセージが表示されること" do
        post taste_diagnosis_path, params: {
          answers: { chocolate: "milk_chocolate" }  # 1問だけ回答
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("全ての質問に回答してください")
      end
    end

    context "既に診断済みの場合" do
      before { create(:taste_profile, user: user) }

      it "診断結果が上書きされること" do
        expect {
          post taste_diagnosis_path, params: { answers: valid_answers }
        }.not_to change(TasteProfile, :count)

        # diagnosed_atが更新されているか確認
        profile = user.reload.taste_profile
        expect(profile.diagnosed_at).to be_within(1.second).of(Time.current)
      end
    end
  end
end
