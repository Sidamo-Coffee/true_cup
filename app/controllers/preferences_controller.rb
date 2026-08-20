class PreferencesController < ApplicationController
  before_action :authenticate_user!

  def show
    @scope = %w[all liked].include?(params[:scope]) ? params[:scope] : "all"
    @preference = PreferenceSummary.new(current_user, scope: @scope).call

    # おすすめ本体も、その確からしさ・進み具合も、このページには置かない（#143）。
    # 診断とのズレの比較相手として、★4以上の集計だけが必要。
    preference_liked = PreferenceSummary.new(current_user, scope: :liked).call

    # 診断と実際のズレ。診断は「好みの強さ」なので、比較相手は★4以上の記録（#120）
    @diagnosis_gap = DiagnosisGap.new(
      taste_profile: current_user.taste_profile,
      preference_liked: preference_liked
    ).call
  end
end
