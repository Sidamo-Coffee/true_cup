require "test_helper"

class TasteProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user          = users(:one)
    @taste_profile = taste_profiles(:one)  # ここで fixture をそのまま利用
    sign_in @user
  end

  test "should get show" do
    get taste_profile_url
    assert_response :success
  end
end
