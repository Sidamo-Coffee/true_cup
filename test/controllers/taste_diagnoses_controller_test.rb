require "test_helper"

class TasteDiagnosesControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get taste_diagnoses_new_url
    assert_response :success
  end

  test "should get create" do
    get taste_diagnoses_create_url
    assert_response :success
  end
end
