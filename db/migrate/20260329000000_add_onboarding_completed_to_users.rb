class AddOnboardingCompletedToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :onboarding_completed, :boolean, default: false, null: false
  end
end
