require "test_helper"

class MypageControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "should get show" do
    sign_in @user
    get mypage_url
    assert_response :success
  end
end
