require 'rails_helper'

RSpec.describe "Mypage", type: :request do
  let(:user) { create(:user) }

  describe "GET /mypage" do
    context "ログインしていない場合" do
      it "ログインページにリダイレクトされること" do
        get mypage_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "ログインしている場合" do
      before { sign_in user }

      it "マイページが表示されること" do
        get mypage_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include("マイページ")
      end

      it "挨拶の横にコーヒーアイコンが表示されること" do
        get mypage_path
        expect(response.body).to include('data-illustration="coffee-icon"')
      end

      it "オンボーディングの各ステップに異なるイラストが表示されること" do
        get mypage_path

        # data-step 属性は必ず異なるため、SVGの中身（描画内容）だけを比較する
        drawings = response.body.scan(%r{<svg[^>]*data-illustration="coffee-step"[^>]*>(.*?)</svg>}m).flatten
        expect(drawings.size).to eq(I18n.t("shared.onboarding_modal.steps").size)
        expect(drawings.uniq.size).to eq(drawings.size)
      end

      context "焙煎度が全て不明の記録しかない場合" do
        before { 3.times { create(:coffee_log, user: user, roast_level: :unknown) } }

        it "エラーにならず表示できること" do
          get mypage_path
          expect(response).to have_http_status(:success)
        end

        it "焙煎度を記録するよう促すメッセージが表示されること" do
          get mypage_path
          expect(response.body).to include(I18n.t("mypage.show.insights.unknown_roast_only"))
        end

        it "記録が1件もない旨のメッセージは表示しないこと" do
          get mypage_path
          expect(response.body).not_to include(I18n.t("mypage.show.insights.empty_all"))
        end
      end

      context "味覚診断が未実施の場合" do
        it "診断を促すメッセージが表示されること" do
          get mypage_path
          expect(response.body).to include("味覚診断をはじめる")
        end
      end

      context "味覚診断済みの場合" do
        let(:user) { create(:user, :with_taste_profile) }

        it "診断結果が表示されること" do
          get mypage_path
          expect(response.body).to include("味覚診断結果")
        end
      end

      context "コーヒー記録がある場合" do
        let(:user) { create(:user, :with_coffee_logs) }

        it "最新の記録が表示されること" do
          get mypage_path
          expect(response.body).to include(ERB::Util.html_escape(user.coffee_logs.first.coffee_name))
        end
      end
    end
  end
end
