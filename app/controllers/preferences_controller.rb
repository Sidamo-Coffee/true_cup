class PreferencesController < ApplicationController
  before_action :authenticate_user!

  def show
    @scope = %w[all liked].include?(params[:scope]) ? params[:scope] : "all"
    @preference = PreferenceSummary.new(current_user, scope: @scope).call

    # おすすめの確からしさを表示するため、選択中のタブに関わらず両スコープを集計する。
    # RecommendedRoast が liked / all の両方を根拠の判定に使うため（#118）。
    preference_liked = PreferenceSummary.new(current_user, scope: :liked).call

    @recommended_roast = RecommendedRoast.new(
      preference_liked: preference_liked,
      preference_all: PreferenceSummary.new(current_user, scope: :all).call,
      taste_profile: current_user.taste_profile
    ).call

    # 診断と実際のズレ。診断は「好みの強さ」なので、比較相手は★4以上の記録（#120）
    @diagnosis_gap = DiagnosisGap.new(
      taste_profile: current_user.taste_profile,
      preference_liked: preference_liked
    ).call
  end
end
