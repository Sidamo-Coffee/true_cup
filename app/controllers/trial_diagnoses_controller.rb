class TrialDiagnosesController < ApplicationController
  skip_before_action :authenticate_user!

  def new
    @questions = TasteDiagnosisLogic.questions
    @form_url = trial_diagnosis_path
    render "taste_diagnoses/new" # 見た目を揃える（テンプレ流用）
  end

  def create
    @questions = TasteDiagnosisLogic.questions
    @form_url = trial_diagnosis_path
    answers = TasteDiagnosisLogic.extract_answers(params[:answers])
    if answers.nil?
      flash.now[:alert] = t("flash.taste_diagnoses.create.answers_nil")
      return render "taste_diagnoses/new", status: :unprocessable_entity
    end

    result = TasteDiagnosisLogic.diagnose(answers)
    redirect_to trial_result_path(type: result.preferred_roast)
  end
end
