require 'rails_helper'

RSpec.describe "TrialResults", type: :request do
  describe "GET /trial_results/:type" do
    it "未ログインでも試し診断の結果ページが表示されること" do
      get trial_result_path(type: "medium")
      expect(response).to have_http_status(:success)
      expect(response.body).to include(I18n.t("taste_profiles.show.heading"))
    end

    it "焙煎度に対応したイラストが表示されること" do
      get trial_result_path(type: "dark")
      expect(response.body).to include('data-illustration="coffee-roast"')
      expect(response.body).to include('data-roast="dark"')
    end

    it "焙煎度ごとにイラストの配色が変わること" do
      # data-roast 属性は必ず異なるため、SVGの中身（配色）だけを比較する
      drawings = %w[light medium medium_dark dark].map do |roast|
        get trial_result_path(type: roast)
        response.body[%r{<svg[^>]*data-illustration="coffee-roast"[^>]*>(.*?)</svg>}m, 1]
      end

      expect(drawings).to all(be_present)
      expect(drawings.uniq.size).to eq(drawings.size)
    end

    context "不正な焙煎度が指定された場合" do
      it "ルーティングにマッチせず404になること" do
        get "/trial_results/invalid_roast"
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
