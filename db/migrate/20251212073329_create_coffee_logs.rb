class CreateCoffeeLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :coffee_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.date :drank_on, null: false
      t.string :coffee_name
      t.integer :place, null: false, default: 0
      t.string :cafe_name
      t.integer :roast_level, null: false, default: 0
      t.integer :brew_method
      t.integer :bitterness, null: false
      t.integer :acidity, null: false
      t.integer :sweetness
      t.integer :body
      t.integer :overall_rating, null: false
      t.text :memo

      t.timestamps
    end
  end
end
