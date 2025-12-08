require "test_helper"

class TasteDiagnosesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one) # test/fixtures/users.yml のユーザー名
    sign_in @user
  end

  test "should get new" do
    get new_taste_diagnosis_url
    assert_response :success
  end

  test "should get create" do
    post taste_diagnosis_url, params: {
      answers: {
        chocolate: "dark_chocolate",
        cake:      "mont_blanc",
        dressing:  "japanese_dressing",
        amount:    "little",
        dislike:   "too_sour"
      }
    }

    # 診断成功時は taste_profile_path にリダイレクトする想定
    assert_redirected_to taste_profile_url
  end
end
