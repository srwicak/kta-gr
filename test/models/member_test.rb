require "test_helper"

class MemberTest < ActiveSupport::TestCase
  setup do
    KtaSequence.delete_all
    Wilayah.delete_all
    setup_wilayah
  end

  test "assigns incrementing letter sequence per month" do
    travel_to Time.zone.local(2025, 1, 15, 12, 0, 0) do
      first_member = build_member("1201010101010001", "081234567890")
      assert_equal 1, first_member.letter_sequence
      assert_equal 1, first_member.letter_month
      assert_equal 2025, first_member.letter_year

      second_member = build_member("1201010101010002", "081234567891")
      assert_equal 2, second_member.letter_sequence
      assert_equal 1, second_member.letter_month
      assert_equal 2025, second_member.letter_year
    end

    travel_to Time.zone.local(2025, 2, 1, 10, 0, 0) do
      third_member = build_member("1201010101010003", "081234567892")
      assert_equal 1, third_member.letter_sequence
      assert_equal 2, third_member.letter_month
      assert_equal 2025, third_member.letter_year
    end
  end

  test "generates formatted letter and nagr numbers" do
    travel_to Time.zone.local(2025, 3, 5, 9, 0, 0) do
      member = build_member("1201010101010004", "081234567893")
      assert_match %r{\A\d{3}/DPP-GERAK/NAGR/III/2025\z}, member.letter_number
      expected_suffix = member.kta_number[-6, 6]
      assert_equal "NAGR.120101.#{expected_suffix}", member.nagr_number
    end
  end

  private

  def build_member(nik, phone)
    Member.create!(name: "Test Anggota", nik: nik, phone: phone)
  end

  def setup_wilayah
    Wilayah.create!(code_norm: "12", code_dotted: "12", level: 1, name: "Provinsi Test", parent_code_norm: nil)
    Wilayah.create!(code_norm: "1201", code_dotted: "12.01", level: 2, name: "Kabupaten Test", parent_code_norm: "12")
    Wilayah.create!(code_norm: "120101", code_dotted: "12.01.01", level: 3, name: "Kecamatan Test", parent_code_norm: "1201")
  end
end
