require 'rails_helper'

RSpec.describe TasteProfile, type: :model do
  describe 'バリデーション' do
    subject { build(:taste_profile) }

    it { is_expected.to validate_presence_of(:taste_type) }
    it { is_expected.to validate_presence_of(:preferred_roast) }
    it { is_expected.to validate_presence_of(:diagnosed_at) }

    it { is_expected.to validate_presence_of(:bitterness_score) }
    it { is_expected.to validate_numericality_of(:bitterness_score).only_integer.is_in(0..10) }

    it { is_expected.to validate_presence_of(:acidity_score) }
    it { is_expected.to validate_numericality_of(:acidity_score).only_integer.is_in(0..10) }

    it { is_expected.to validate_presence_of(:sweetness_score) }
    it { is_expected.to validate_numericality_of(:sweetness_score).only_integer.is_in(0..10) }

    it { is_expected.to validate_presence_of(:body_score) }
    it { is_expected.to validate_numericality_of(:body_score).only_integer.is_in(0..10) }
  end

  describe 'アソシエーション' do
    it { is_expected.to belong_to(:user) }
  end

  describe 'enum' do
    it { is_expected.to define_enum_for(:preferred_roast).with_values(light: 0, medium: 1, medium_dark: 2, dark: 3) }
    it { is_expected.to define_enum_for(:taste_type).with_values(light_like: 0, medium_like: 1, medium_dark_like: 2, dark_like: 3) }
  end

  describe 'ファクトリ' do
    it '有効なファクトリを持つこと' do
      expect(build(:taste_profile)).to be_valid
    end

    it '浅煎りタイプのファクトリが正しく動作すること' do
      profile = create(:taste_profile, :light_like)
      expect(profile.preferred_roast).to eq('light')
      expect(profile.taste_type).to eq('light_like')
    end

    it '深煎りタイプのファクトリが正しく動作すること' do
      profile = create(:taste_profile, :dark_like)
      expect(profile.preferred_roast).to eq('dark')
      expect(profile.taste_type).to eq('dark_like')
    end
  end

  describe 'スコアのバリデーション' do
    it 'スコアが0未満の場合、無効であること' do
      profile = build(:taste_profile, bitterness_score: -1)
      expect(profile).not_to be_valid
    end

    it 'スコアが10より大きい場合、無効であること' do
      profile = build(:taste_profile, acidity_score: 11)
      expect(profile).not_to be_valid
    end

    it 'スコアが小数の場合、無効であること' do
      profile = build(:taste_profile, sweetness_score: 5.5)
      expect(profile).not_to be_valid
    end
  end
end
