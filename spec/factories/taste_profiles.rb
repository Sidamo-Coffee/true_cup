FactoryBot.define do
  factory :taste_profile do
    association :user

    taste_type { :medium_like }
    description { "全体のバランスが良いタイプです。気分やシーンに合わせて幅広いコーヒーを楽しめます。" }
    bitterness_score { 5 }
    acidity_score { 5 }
    sweetness_score { 5 }
    body_score { 5 }
    preferred_roast { :medium }
    diagnosed_at { Time.current }

    # 浅煎りタイプ
    trait :light_like do
      taste_type { :light_like }
      preferred_roast { :light }
      bitterness_score { 2 }
      acidity_score { 8 }
      sweetness_score { 6 }
      body_score { 3 }
      description { "フルーツのような酸味や爽やかさを楽しめる、浅煎りタイプです。" }
    end

    # 深煎りタイプ
    trait :dark_like do
      taste_type { :dark_like }
      preferred_roast { :dark }
      bitterness_score { 9 }
      acidity_score { 2 }
      sweetness_score { 4 }
      body_score { 9 }
      description { "ビターな味わいとどっしりしたコクが際立つ、深煎りタイプです。" }
    end
  end
end
