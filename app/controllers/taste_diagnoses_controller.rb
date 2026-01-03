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

    begin
      TasteDiagnosisLogic.apply_result_to_user!(user: current_user, result: result)
      redirect_to taste_profile_path, notice: t("flash.taste_diagnoses.create.notice")
    rescue ActiveRecord::RecordInvalid
      flash.now[:alert] = t("flash.taste_diagnoses.create.alert")
      render :new, status: :unprocessable_entity
    end
  end
end
