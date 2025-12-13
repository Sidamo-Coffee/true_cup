class MypageController < ApplicationController
  def show
    @user = current_user
    @taste_profile = current_user.taste_profile
    @recent_coffee_logs = current_user.coffee_logs.order(drank_on: :desc, created_at: :desc).limit(3)
  end
end
