class TrialResultsController < ApplicationController
  skip_before_action :authenticate_user!

  def show
    @roast_key = params[:type].to_s

    unless TasteDiagnosisLogic.valid_roast_key?(@roast_key)
      return redirect_to trial_diagnosis_path, alert: t("flash.taste_diagnoses.create.answers_nil")
    end

    @description = TasteDiagnosisLogic.description_for(@roast_key)

    roast_label = t("taste_profiles.show.roast_label.#{@roast_key}", default: t("taste_profiles.show.roast_label.default"))
    tagline     = t("taste_profiles.show.tagline.#{@roast_key}", default: t("taste_profiles.show.tagline.default"))

    share_text = t("taste_profiles.show.share.text", tagline: tagline, roast: roast_label)
    page_url   = trial_result_url(type: @roast_key)

    @x_share_url = TasteDiagnosisLogic.build_x_share_url(text: share_text, url: page_url)
    @from_trial = cookies.encrypted[:trial_answers].present?
  end
end
