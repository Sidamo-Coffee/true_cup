class StaticPagesController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[top]

  def top; end

  private

  def redirect_if_authenticated
    redirect_to mypage_path if user_signed_in?
  end
end
