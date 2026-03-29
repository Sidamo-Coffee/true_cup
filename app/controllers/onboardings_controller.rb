class OnboardingsController < ApplicationController
  def complete
    current_user.update!(onboarding_completed: true)
    head :ok
  end
end
