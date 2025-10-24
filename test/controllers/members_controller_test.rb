require "test_helper"

class MembersControllerTest < ActionDispatch::IntegrationTest
  setup do
    KtaSequence.delete_all
    Wilayah.delete_all
    setup_wilayah
    @member = Member.create!(name: "Tester", nik: "1201010101010005", phone: "081234567894")
  end

  test "serves membership letter pdf without login when token valid" do
    token = @member.signed_id(purpose: :membership_letter)
    get letter_member_path(@member, format: :pdf, token: token)
    assert_response :success
    assert_equal "application/pdf", response.media_type
  end

  test "returns not found when token missing" do
    get letter_member_path(@member, format: :pdf)
    assert_response :not_found
  end

  test "returns not found when token invalid" do
    get letter_member_path(@member, format: :pdf, token: "invalid")
    assert_response :not_found
  end

  private

  def setup_wilayah
    Wilayah.create!(code_norm: "12", code_dotted: "12", level: 1, name: "Provinsi Test", parent_code_norm: nil)
    Wilayah.create!(code_norm: "1201", code_dotted: "12.01", level: 2, name: "Kabupaten Test", parent_code_norm: "12")
    Wilayah.create!(code_norm: "120101", code_dotted: "12.01.01", level: 3, name: "Kecamatan Test", parent_code_norm: "1201")
  end
end
