require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'バリデーション' do
    subject { build(:user) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(50) }
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
  end

  describe 'アソシエーション' do
    it { is_expected.to have_one(:taste_profile).dependent(:destroy) }
    it { is_expected.to have_many(:coffee_logs).dependent(:destroy) }
  end

  describe 'ファクトリ' do
    it '有効なファクトリを持つこと' do
      expect(build(:user)).to be_valid
    end

    it '診断済みユーザーのファクトリが正しく動作すること' do
      user = create(:user, :with_taste_profile)
      expect(user.taste_profile).to be_present
    end

    it 'コーヒー記録を持つユーザーのファクトリが正しく動作すること' do
      user = create(:user, :with_coffee_logs)
      expect(user.coffee_logs.count).to eq(3)
    end
  end

  describe 'バリデーションエラー' do
    it '名前が空の場合、無効であること' do
      user = build(:user, name: nil)
      expect(user).not_to be_valid
      expect(user.errors.added?(:name, :blank)).to be true
    end

    it '名前が51文字の場合、無効であること' do
      user = build(:user, name: 'a' * 51)
      expect(user).not_to be_valid
      expect(user.errors.added?(:name, :too_long, count: 50)).to be true
    end

    it 'メールアドレスが重複している場合、無効であること' do
      create(:user, email: 'duplicate@example.com')
      user = build(:user, email: 'duplicate@example.com')
      expect(user).not_to be_valid
      expect(user.errors.details[:email]).to include(a_hash_including(error: :taken))
    end
  end
end