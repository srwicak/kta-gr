# Test login functionality
puts "=" * 60
puts "TEST LOGIN MEMBER"
puts "=" * 60

# Buat member test
Member.destroy_all
KtaSequence.destroy_all

member = Member.new(
  name: "Test Login User",
  phone: "081234567890",
  nik: "3201012001010001",
)

member.dom_area2_code = member.area2_code
member.dom_area4_code = member.area4_code
member.dom_area6_code = member.area6_code

if member.save
  puts "\n✓ Member berhasil dibuat"
  puts "  Nama: #{member.name}"
  puts "  NIK: #{member.nik}"
  puts "  Phone: #{member.phone}"

  # Test 1: Cari dengan find_by_nik_plain
  puts "\n🔍 Test 1: find_by_nik_plain"
  found = Member.find_by_nik_plain("3201012001010001")
  if found
    puts "  ✓ Member ditemukan"
    puts "  ID: #{found.id}"
  else
    puts "  ✗ Member TIDAK ditemukan"
  end

  # Test 2: Cari dengan find_by
  puts "\n🔍 Test 2: find_by(nik:)"
  found2 = Member.find_by(nik: "3201012001010001")
  if found2
    puts "  ✓ Member ditemukan"
    puts "  ID: #{found2.id}"
  else
    puts "  ✗ Member TIDAK ditemukan"
  end

  # Test 3: Authenticate
  puts "\n🔐 Test 3: Authenticate password"
  if found && found.authenticate("081234567890")
    puts "  ✓ Password benar (nomor HP cocok)"
  elsif found
    puts "  ✗ Password salah"
    puts "  Password digest: #{found.password_digest.present? ? "ada" : "tidak ada"}"
  end

  # Test 4: Simulate full login
  puts "\n🔐 Test 4: Simulate full login process"
  test_nik = "3201012001010001"
  test_phone = "081234567890"

  login_member = Member.find_by_nik_plain(test_nik)
  if login_member
    puts "  ✓ Member ditemukan dengan NIK"
    if login_member.authenticate(test_phone)
      puts "  ✓ Login BERHASIL!"
    else
      puts "  ✗ Password salah"
      # Debug password
      puts "\n  DEBUG INFO:"
      puts "  - password_digest present: #{login_member.password_digest.present?}"
      puts "  - Input phone: #{test_phone}"
      puts "  - Stored phone: #{login_member.phone}"

      # Try to set password manually
      login_member.password = test_phone
      if login_member.save(validate: false)
        puts "  - Password reset berhasil"
        if login_member.authenticate(test_phone)
          puts "  ✓ Setelah reset, login BERHASIL!"
        end
      end
    end
  else
    puts "  ✗ Member tidak ditemukan"
  end
else
  puts "\n✗ Gagal membuat member:"
  member.errors.full_messages.each { |m| puts "  - #{m}" }
end

puts "\n" + "=" * 60
puts "TEST SELESAI"
puts "=" * 60
