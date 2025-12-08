require "test_helper"

class TasteProfilesControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    get taste_profiles_show_url
    assert_response :success
  end
end
