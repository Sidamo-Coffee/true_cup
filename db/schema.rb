# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2025_12_13_075054) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "coffee_logs", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.date "drank_on", null: false
    t.string "coffee_name"
    t.integer "place", default: 0, null: false
    t.string "cafe_name"
    t.integer "roast_level", default: 0, null: false
    t.integer "brew_method", default: 0
    t.integer "bitterness", null: false
    t.integer "acidity", null: false
    t.integer "sweetness"
    t.integer "body"
    t.integer "overall_rating", null: false
    t.text "memo"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_coffee_logs_on_user_id"
  end

  create_table "taste_profiles", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "taste_type", null: false
    t.text "description"
    t.integer "bitterness_score", null: false
    t.integer "acidity_score", null: false
    t.integer "sweetness_score", null: false
    t.integer "body_score", null: false
    t.integer "preferred_roast", null: false
    t.datetime "diagnosed_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_taste_profiles_on_user_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "coffee_logs", "users"
  add_foreign_key "taste_profiles", "users"
end
