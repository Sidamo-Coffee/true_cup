FactoryBot.define do
  factory :user do
    sequence(:name) { |n| "テストユーザー#{n}" }
    sequence(:email) { |n| "test#{n}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }

    # 診断済みユーザー
    trait :with_taste_profile do
      after(:create) do |user|
        create(:taste_profile, user: user)
      end
    end

    # コーヒー記録を持つユーザー
    trait :with_coffee_logs do
      after(:create) do |user|
        create_list(:coffee_log, 3, user: user)
      end
    end
  end
end
