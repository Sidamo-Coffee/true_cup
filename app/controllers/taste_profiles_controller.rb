class TasteProfilesController < ApplicationController
  before_action :authenticate_user!

  def show
    @taste_profile = current_user.taste_profile

    unless @taste_profile
      redirect_to new_taste_diagnosis_path, alert: t("flash.taste_profiles.show.alert")
    end
  end
end
