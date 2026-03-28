# frozen_string_literal: true

class Users::RegistrationsController < Devise::RegistrationsController
  # before_action :configure_sign_up_params, only: [:create]
  # before_action :configure_account_update_params, only: [:update]
  before_action :authenticate_user!, only: [:confirm_deletion]

  def confirm_deletion
    @user = current_user
  end

  # GET /resource/sign_up
  # def new
  #   super
  # end

  # POST /resource
  # def create
  #   super
  # end

  # GET /resource/edit
  # def edit
  #   super
  # end

  # PUT /resource
  # def update
  #   super
  # end

  # DELETE /resource
  def destroy
    unless current_user.valid_password?(params[:current_password])
      redirect_to confirm_deletion_user_registration_path, alert: "パスワードが正しくありません。" and return
    end

    super do |resource|
      Rails.logger.info "User #{resource.id} (#{resource.email}) deleted their account"
    end
  end

  # GET /resource/cancel
  # Forces the session data which is usually expired after sign
  # in to be expired now. This is useful if the user wants to
  # cancel oauth signing in/up in the middle of the process,
  # removing all OAuth session data.
  # def cancel
  #   super
  # end

  protected

  # If you have extra params to permit, append them to the sanitizer.
  # def configure_sign_up_params
  #   devise_parameter_sanitizer.permit(:sign_up, keys: [:attribute])
  # end

  # If you have extra params to permit, append them to the sanitizer.
  # def configure_account_update_params
  #   devise_parameter_sanitizer.permit(:account_update, keys: [:attribute])
  # end
  def after_sign_up_path_for(resource)
    raw = cookies.encrypted[:trial_answers]

    if raw.present?
      begin
        parsed = JSON.parse(raw) # {"chocolate"=>"...", ...}
        answers = TasteDiagnosisLogic.extract_answers(ActionController::Parameters.new(answers: parsed)[:answers])

        if answers.present?
          result = TasteDiagnosisLogic.diagnose(answers)
          TasteDiagnosisLogic.apply_result_to_user!(user: resource, result: result)
        end
      rescue JSON::ParserError
        # 何もしない（trial無し扱いで通常フローへ）
      ensure
        cookies.delete(:trial_answers)
      end

      # ★ trialあり：診断済みとしてマイページへ
      return mypage_path
    end

    # ★ trialなし：従来どおり診断へ
    new_taste_diagnosis_path
  end
  
  def after_inactive_sign_up_path_for(resource)
    root_path
  end
end
