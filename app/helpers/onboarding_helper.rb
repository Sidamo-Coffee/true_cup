module OnboardingHelper
  def show_onboarding_modal?
    user_signed_in? && !current_user.onboarding_completed?
  end
end
