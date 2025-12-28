# app/controllers/taste_diagnoses_controller.rb
class TasteDiagnosesController < ApplicationController
  before_action :authenticate_user!

  def new
    @questions = TasteDiagnosisLogic.questions
    @form_url = taste_diagnosis_path
  end

  def create
    @questions = TasteDiagnosisLogic.questions
    @form_url = taste_diagnosis_path

    answers = TasteDiagnosisLogic.extract_answers(params[:answers])
    if answers.nil?
      flash.now[:alert] = t("flash.taste_diagnoses.create.answers_nil")
      return render :new, status: :unprocessable_entity
    end

    result = TasteDiagnosisLogic.diagnose(answers)

    taste_profile = current_user.taste_profile || current_user.build_taste_profile
    taste_profile.assign_attributes(
      taste_type:        result.taste_type,
      description:       result.description,
      bitterness_score:  result.scores[:bitterness],
      acidity_score:     result.scores[:acidity],
      sweetness_score:   result.scores[:sweetness],
      body_score:        result.scores[:body],
      preferred_roast:   result.preferred_roast,
      diagnosed_at:      Time.current
    )

    if taste_profile.save
      redirect_to taste_profile_path, notice: t("flash.taste_diagnoses.create.notice")
    else
      flash.now[:alert] = t("flash.taste_diagnoses.create.alert")
      render :new, status: :unprocessable_entity
    end
  end
end
