class MypageController < ApplicationController
  def show
    @user = current_user
    @taste_profile = current_user.taste_profile
  end
end
