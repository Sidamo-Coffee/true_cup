require 'rails_helper'

RSpec.describe CoffeeLog, type: :model do
  describe 'バリデーション' do
    subject { build(:coffee_log) }

    it { is_expected.to validate_presence_of(:drank_on) }
    it { is_expected.to validate_presence_of(:place) }
    it { is_expected.to validate_presence_of(:roast_level) }
    it { is_expected.to validate_presence_of(:bitterness) }
    it { is_expected.to validate_presence_of(:acidity) }
    it { is_expected.to validate_presence_of(:overall_rating) }
    
    it { is_expected.to validate_length_of(:coffee_name).is_at_most(100) }
    it { is_expected.to validate_length_of(:cafe_name).is_at_most(100) }
    it { is_expected.to validate_length_of(:memo).is_at_most(1000) }
    
    it { is_expected.to validate_numericality_of(:bitterness).only_integer.is_in(0..2) }
    it { is_expected.to validate_numericality_of(:acidity).only_integer.is_in(0..2) }
    it { is_expected.to validate_numericality_of(:overall_rating).only_integer.is_in(1..5) }
  end

  describe 'アソシエーション' do
    it { is_expected.to belong_to(:user) }
  end

  describe 'enum' do
    it { is_expected.to define_enum_for(:place).with_values(cafe: 0, home: 1, other: 99).with_prefix(:place) }
    it { is_expected.to define_enum_for(:roast_level).with_values(unknown: 0, light: 1, medium: 2, medium_dark: 3, dark: 4).with_prefix(:roast_level) }
    it { is_expected.to define_enum_for(:brew_method).with_values(unknown: 0, pour_over: 1, nel: 2, espresso: 3, french_press: 4, other: 99).with_prefix(:brew_method) }
  end

  describe 'ファクトリ' do
    it '有効なファクトリを持つこと' do
      expect(build(:coffee_log)).to be_valid
    end

    it '自宅で飲んだコーヒーのファクトリが正しく動作すること' do
      log = create(:coffee_log, :home_brew)
      expect(log.place).to eq('home')
      expect(log.cafe_name).to be_nil
    end

    it '浅煎りコーヒーのファクトリが正しく動作すること' do
      log = create(:coffee_log, :light_roast)
      expect(log.roast_level).to eq('light')
      expect(log.bitterness).to eq(0)
    end
  end

  describe 'バリデーションエラー' do
    it '苦味が範囲外の場合、無効であること' do
      log = build(:coffee_log, bitterness: 3)
      expect(log).not_to be_valid
    end

    it '酸味が範囲外の場合、無効であること' do
      log = build(:coffee_log, acidity: -1)
      expect(log).not_to be_valid
    end

    it '総合評価が1未満の場合、無効であること' do
      log = build(:coffee_log, overall_rating: 0)
      expect(log).not_to be_valid
    end

    it '総合評価が5より大きい場合、無効であること' do
      log = build(:coffee_log, overall_rating: 6)
      expect(log).not_to be_valid
    end
  end
end