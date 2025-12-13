class CoffeeLog < ApplicationRecord
  belongs_to :user

  enum place: { cafe: 0, home: 1, other: 99 }, _prefix: true
  enum roast_level: { unknown: 0, light: 1, medium: 2, medium_dark: 3, dark: 4 }, _prefix: true
  enum brew_method: { unknown: 0, pour_over: 1, nel: 2, espresso: 3, french_press: 4, other: 99 }, _prefix: true

  validates :drank_on, :place, :roast_level, :bitterness, :acidity, :overall_rating, presence: true
  validates :coffee_name, length: { maximum: 100 }, allow_blank: true
  validates :cafe_name, length: { maximum: 100 }, allow_blank: true
  validates :memo, length: { maximum: 1000 }, allow_blank: true
  validates :bitterness, :acidity, numericality: { only_integer: true, in: 0..2 }
  validates :overall_rating, numericality: { only_integer: true, in: 1..5 }
end
