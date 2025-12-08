class TasteProfile < ApplicationRecord
  belongs_to :user

  enum preferred_roast: {
    light: 0,        # 浅煎りタイプ
    medium: 1,       # 中煎りタイプ
    medium_dark: 2,  # 中深煎りタイプ
    dark: 3          # 深煎りタイプ
  }

  # 味覚タイプ（MVPでは preferred_roast とほぼ同義でOK）
  enum taste_type: {
    light_like: 0,
    medium_like: 1,
    medium_dark_like: 2,
    dark_like: 3
  }

  validates :bitterness_score, :acidity_score, :sweetness_score, :body_score,
            presence: true,
            numericality: { only_integer: true, in: 1..5 }
  validates :diagnosed_at, :taste_type, :preferred_roast, presence: true
end
