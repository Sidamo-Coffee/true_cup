# frozen_string_literal: true

class Users::RegistrationsController < Devise::RegistrationsController
  # before_action :configure_sign_up_params, only: [:create]
  # before_action :configure_account_update_params, only: [:update]
  # devise コントローラー内では authenticate_user! が force オプションなしでは素通りするため、
  # Devise 標準の authenticate_scope!（内部で force: true を渡す）で保護する。
  # 同名コールバックの再宣言は既存の条件を置き換えるため、Devise 既定の対象アクションもここに含めること。
  prepend_before_action :authenticate_scope!, only: [ :edit, :update, :destroy, :confirm_deletion ]

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
    return new_taste_diagnosis_path if raw.blank?

    # 引き継げたときだけ「診断済み」としてマイページへ送る。
    # 失敗したのにマイページへ送ると、TasteProfile が無いまま診断済み前提の画面に立たされる（#151）
    apply_trial_answers(resource, raw) ? mypage_path : new_taste_diagnosis_path
  end

  def after_inactive_sign_up_path_for(resource)
    root_path
  end

  private

  # 試し診断の回答を診断結果として保存する。引き継げたら true。
  #
  # 登録そのものは成功しているため、引き継ぎの失敗で登録を巻き戻さない。
  # Cookie は成否によらず捨てる。壊れた Cookie を残しても次に読んだときまた失敗するだけのため。
  def apply_trial_answers(user, raw)
    parsed = JSON.parse(raw)
    return false unless parsed.is_a?(Hash)

    answers = TasteDiagnosisLogic.extract_answers(
      ActionController::Parameters.new(answers: parsed)[:answers]
    )
    return false if answers.blank?

    result = TasteDiagnosisLogic.diagnose(answers)
    TasteDiagnosisLogic.apply_result_to_user!(user: user, result: result)
    true
  rescue JSON::ParserError, ActiveRecord::RecordInvalid => e
    Rails.logger.warn("試し診断の引き継ぎに失敗しました: #{e.class}")
    false
  ensure
    cookies.delete(:trial_answers)
  end
end
