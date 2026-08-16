require 'rails_helper'

# public/ 配下の静的エラーページはRailsを経由しないため、ファイルの内容を直接検証する
RSpec.describe "静的エラーページ" do
  {
    "400" => "リクエストを処理できません",
    "404" => "ページが見つかりません",
    "422" => "この操作は実行できません",
    "500" => "問題が発生しました"
  }.each do |code, heading|
    describe "public/#{code}.html" do
      let(:html) { Rails.root.join("public", "#{code}.html").read }

      it "Railsのデフォルトではなく、アプリのデザインになっていること" do
        expect(html).not_to include("rails-default-error-page")
        expect(html).to include('<html lang="ja">')
        expect(html).to include(heading)
      end

      it "コーヒーのイラストが装飾として埋め込まれていること" do
        expect(html).to include("<svg")
        expect(html).to include('aria-hidden="true"')
      end

      it "トップページへの導線があること" do
        expect(html).to include('href="/"')
      end
    end
  end
end
