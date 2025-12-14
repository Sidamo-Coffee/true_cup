class CoffeeLogsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_coffee_log, only: %i[show edit update destroy]

  def index
    scope = @coffee_logs = current_user.coffee_logs
                               .includes(:user)
                               .order(drank_on: :desc, created_at: :desc)

    if params[:q].present?
      q = "%#{params[:q]}%"
      scope = scope.where(
        "coffee_name ILIKE :q OR cafe_name ILIKE :q OR memo ILIKE :q",
        q: q
      )
    end

    @coffee_logs = scope.page(params[:page]).per(10)
  end

  def show; end

  def new
    @coffee_log = current_user.coffee_logs.build(
      drank_on: Date.current,
      overall_rating: 3
    )
  end

  def create
    @coffee_log = current_user.coffee_logs.build(coffee_log_params)
    if @coffee_log.save
      redirect_to @coffee_log, notice: "コーヒー記録を登録しました"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @coffee_log.update(coffee_log_params)
      redirect_to @coffee_log, notice: "コーヒー記録を更新しました"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @coffee_log.destroy!
    redirect_to coffee_logs_path, notice: "コーヒー記録を削除しました", status: :see_other
  end

  private

  def set_coffee_log
    @coffee_log = current_user.coffee_logs.find(params[:id])
  end

  def coffee_log_params
    params.require(:coffee_log).permit(
      :drank_on, :coffee_name, :place, :cafe_name, :roast_level, :brew_method,
      :bitterness, :acidity, :overall_rating, :memo
    )
  end
end
