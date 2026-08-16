class PreferencesController < ApplicationController
  before_action :authenticate_user!

  def show
    @scope = %w[all liked].include?(params[:scope]) ? params[:scope] : "all"
    @preference = PreferenceSummary.new(current_user, scope: @scope).call

    # おすすめの確からしさを表示するため、選択中のタブに関わらず両スコープを集計する。
    # RecommendedRoast が liked / all の両方を根拠の判定に使うため（#118）。
    @recommended_roast = RecommendedRoast.new(
      preference_liked: PreferenceSummary.new(current_user, scope: :liked).call,
      preference_all: PreferenceSummary.new(current_user, scope: :all).call,
      taste_profile: current_user.taste_profile
    ).call
  end
end
