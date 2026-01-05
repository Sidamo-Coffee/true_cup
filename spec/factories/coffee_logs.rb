FactoryBot.define do
  factory :coffee_log do
    association :user
    drank_on { Date.current }
    coffee_name { Faker::Coffee.blend_name }
    place { :cafe }
    cafe_name { "カフェ#{Faker::Address.city}" }
    roast_level { :medium }
    brew_method { :pour_over }
    bitterness { 1 }  # 0: 弱い, 1: 普通, 2: 強い
    acidity { 1 }
    overall_rating { 4 }  # 1-5
    memo { "美味しかったです。" }

    # 自宅で飲んだコーヒー
    trait :home_brew do
      place { :home }
      cafe_name { nil }
    end

    # 浅煎りコーヒー
    trait :light_roast do
      roast_level { :light }
      bitterness { 0 }
      acidity { 2 }
    end

    # 深煎りコーヒー
    trait :dark_roast do
      roast_level { :dark }
      bitterness { 2 }
      acidity { 0 }
    end

    # 評価が低い
    trait :low_rating do
      overall_rating { 1 }
      memo { "あまり好みではなかった。" }
    end
  end
end
