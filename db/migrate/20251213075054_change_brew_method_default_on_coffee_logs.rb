class ChangeBrewMethodDefaultOnCoffeeLogs < ActiveRecord::Migration[7.2]
  def change
    change_column_default :coffee_logs, :brew_method, from: nil, to: 0
  end
end
