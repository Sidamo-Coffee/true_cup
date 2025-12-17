class PreferencesController < ApplicationController
  before_action :authenticate_user!

  def show
    @scope = %w[all liked].include?(params[:scope]) ? params[:scope] : "all"
    @preference = PreferenceSummary.new(current_user, scope: @scope).call
  end
end
