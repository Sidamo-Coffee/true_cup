require 'rails_helper'

RSpec.describe "CoffeeLogs", type: :request do
  let(:user) { create(:user) }
  let(:coffee_log) { create(:coffee_log, user: user) }

  before { sign_in user }

  describe "GET /coffee_logs" do
    it "記録一覧ページが表示されること" do
      get coffee_logs_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("コーヒー記録一覧")
    end

    context "記録がある場合" do
      before { create_list(:coffee_log, 3, user: user) }

      it "記録が表示されること" do
        get coffee_logs_path
        user.coffee_logs.each do |log|
          expect(response.body).to include(log.coffee_name)
        end
      end
    end

    context "検索クエリがある場合" do
      before do
        create(:coffee_log, user: user, coffee_name: "ブラジル")
        create(:coffee_log, user: user, coffee_name: "コロンビア")
      end

      it "該当する記録のみが表示されること" do
        get coffee_logs_path, params: { q: "ブラジル" }
        expect(response.body).to include("ブラジル")
        expect(response.body).not_to include("コロンビア")
      end
    end
  end

  describe "GET /coffee_logs/:id" do
    it "記録詳細ページが表示されること" do
      get coffee_log_path(coffee_log)
      expect(response).to have_http_status(:success)
      expect(response.body).to include(coffee_log.coffee_name)
    end
  end

  describe "GET /coffee_logs/new" do
    it "新規記録ページが表示されること" do
      get new_coffee_log_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("コーヒーを記録")
    end
  end

  describe "POST /coffee_logs" do
    let(:valid_params) {
      {
        coffee_log: {
          drank_on: Date.current,
          coffee_name: "テストコーヒー",
          place: "cafe",
          cafe_name: "テストカフェ",
          roast_level: "medium",
          bitterness: 1,
          acidity: 1,
          overall_rating: 4,
          memo: "美味しかった"
        }
      }
    }

    context "有効なパラメータの場合" do
      it "記録が作成されること" do
        expect {
          post coffee_logs_path, params: valid_params
        }.to change(user.coffee_logs, :count).by(1)
      end

      it "詳細ページにリダイレクトされること" do
        post coffee_logs_path, params: valid_params
        expect(response).to redirect_to(coffee_log_path(CoffeeLog.last))
      end
    end

    context "無効なパラメータの場合" do
      it "記録が作成されず、エラーが表示されること" do
        invalid_params = valid_params.deep_dup
        invalid_params[:coffee_log][:overall_rating] = 10  # 範囲外

        expect {
          post coffee_logs_path, params: invalid_params
        }.not_to change(CoffeeLog, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "GET /coffee_logs/:id/edit" do
    it "編集ページが表示されること" do
      get edit_coffee_log_path(coffee_log)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("コーヒー記録を編集")
    end
  end

  describe "PATCH /coffee_logs/:id" do
    context "有効なパラメータの場合" do
      it "記録が更新されること" do
        patch coffee_log_path(coffee_log), params: {
          coffee_log: { coffee_name: "更新されたコーヒー" }
        }

        coffee_log.reload
        expect(coffee_log.coffee_name).to eq("更新されたコーヒー")
        expect(response).to redirect_to(coffee_log_path(coffee_log))
      end
    end
  end

  describe "DELETE /coffee_logs/:id" do
    it "記録が削除されること" do
      coffee_log  # 先に作成
      expect {
        delete coffee_log_path(coffee_log)
      }.to change(user.coffee_logs, :count).by(-1)

      expect(response).to redirect_to(coffee_logs_path)
    end
  end

  describe "他のユーザーの記録へのアクセス" do
    let(:other_user) { create(:user) }
    let(:other_log) { create(:coffee_log, user: other_user) }

    it "詳細ページにアクセスできないこと" do
      get coffee_log_path(other_log)
      expect(response).to have_http_status(:not_found)
    end
  end
end
