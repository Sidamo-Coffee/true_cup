class StaticPagesController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[top terms privacy]
  before_action :redirect_if_authenticated, only: %i[top]

  def top; end
  def terms; end
  def privacy; end

  private

  def redirect_if_authenticated
    redirect_to mypage_path if user_signed_in?
  end
end
