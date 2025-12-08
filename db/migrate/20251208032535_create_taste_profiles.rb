class CreateTasteProfiles < ActiveRecord::Migration[7.2]
  def change
    create_table :taste_profiles do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.integer :taste_type, null: false
      t.text :description
      t.integer :bitterness_score, null: false
      t.integer :acidity_score, null: false
      t.integer :sweetness_score, null: false
      t.integer :body_score, null: false
      t.integer :preferred_roast, null: false
      t.datetime :diagnosed_at, null: false

      t.timestamps
    end
  end
end
