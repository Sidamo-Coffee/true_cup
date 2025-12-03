class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  def configure_permitted_parameters
    # 新規登録時に許可する項目
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name])

    # アカウント編集時にも name を使う場合に備えて
    devise_parameter_sanitizer.permit(:account_update, keys: [:name])
  end

  def after_sign_in_path_for(resourse)
    mypage_path
  end

  def after_sign_out_path_for(resourse_or_scope)
    root_path
  end
end
