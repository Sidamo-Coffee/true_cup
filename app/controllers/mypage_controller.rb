class MypageController < ApplicationController
  def show
    @user = current_user
    @taste_profile = current_user.taste_profile
    @recent_coffee_logs = current_user.coffee_logs.order(drank_on: :desc, created_at: :desc).limit(3)
    @preference_all   = PreferenceSummary.new(current_user, scope: :all).call
    @preference_liked = PreferenceSummary.new(current_user, scope: :liked).call
    @recommended_roast = RecommendedRoast.new(
      preference_liked: @preference_liked,
      preference_all: @preference_all,
      taste_profile: @taste_profile
    ).call
    @roast_guide =
      if @recommended_roast&.dig(:available)
        RoastGuide.call(@recommended_roast[:roast_key])
      end
  end
end
