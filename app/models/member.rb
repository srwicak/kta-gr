class Member < ApplicationRecord
  # Active Record Encryption
  encrypts :name
  encrypts :phone, deterministic: true
  encrypts :nik, deterministic: true, downcase: true
  encrypts :kta_number, deterministic: true, downcase: true

  has_secure_password validations: false
  has_one_attached :ktp_photo
  has_one_attached :selfie_photo

  validates :name, :nik, :phone, presence: true

  # Validasi format nama: hanya huruf, spasi, titik, koma, dan apostrof
  validates :name, format: {
           with: /\A[a-zA-Z\s.',-]+\z/,
           message: "hanya boleh berisi huruf, spasi, titik, koma, dan apostrof",
         }, length: { minimum: 3, maximum: 100, message: "harus antara 3-100 karakter" }

  # Validasi format NIK: harus 16 digit angka
  validates :nik, format: {
          with: /\A\d{16}\z/,
          message: "harus berupa 16 digit angka",
        }

  # Validasi format nomor HP Indonesia
  validates :phone, format: {
            with: /\A08\d{8,11}\z/,
            message: "tidak valid. Harus diawali dengan 08 (contoh: 081234567890)",
          }

  validates :nik_fingerprint, uniqueness: { message: "NIK sudah terdaftar. Satu NIK hanya bisa mendaftar satu kali." }
  validates :phone_fingerprint, uniqueness: { message: "Nomor HP sudah terdaftar. Gunakan nomor HP yang berbeda." }
  validates :ktp_photo, presence: { message: "Foto KTP harus diupload" }, on: :create
  validates :selfie_photo, presence: { message: "Foto Selfie harus diupload" }, on: :create
  validate :domicile_or_ktp_address_present, on: :create

  before_validation :set_defaults_from_nik, on: :create
  before_validation :set_initial_password_from_phone, on: :create
  before_create :assign_kta_number
  before_create :assign_membership_letter_number

  def set_defaults_from_nik
    s = nik.to_s.gsub(/\D/, "")
    return if s.length < 12
    self.area2_code ||= s[0, 2]
    self.area4_code ||= s[0, 4]
    self.area6_code ||= s[0, 6]

    dd = s[6, 2].to_i; mm = s[8, 2].to_i; yy = s[10, 2].to_i
    female = dd >= 40; day = female ? dd - 40 : dd
    cur = Date.current.year % 100
    year = (yy <= cur ? 2000 + yy : 1900 + yy)
    if Date.valid_date?(year, mm, day)
      self.birthdate ||= Date.new(year, mm, day)
      self.gender ||= (female ? "Perempuan" : "Laki-laki")
    end
    self.nik_fingerprint ||= Digest::SHA256.hexdigest(s)

    # Set phone fingerprint (check jika column exists)
    if phone.present? && respond_to?(:phone_fingerprint=)
      phone_clean = phone.to_s.gsub(/\D/, "")
      self.phone_fingerprint ||= Digest::SHA256.hexdigest(phone_clean)
    end
  end

  def set_initial_password_from_phone
    if password_digest.blank? && phone.present?
      # Normalize phone number for password
      phone_clean = phone.to_s.gsub(/\D/, "")
      self.password = phone_clean
    end
  end

  def domicile_or_ktp_address_present
    # Pastikan ada alamat lengkap (dari domisili atau KTP)
    prov = dom_area2_code.presence || area2_code
    kota = dom_area4_code.presence || area4_code
    kec = dom_area6_code.presence || area6_code

    if prov.blank? || kota.blank? || kec.blank?
      errors.add(:base, "Alamat domisili harus diisi lengkap (Provinsi, Kota, Kecamatan)")
    end
  end

  def assign_kta_number
    # Gunakan alamat domisili jika ada, kalau tidak pakai alamat KTP
    prov_code = (dom_area2_code.presence || area2_code)
    kota_code = (dom_area4_code.presence || area4_code)
    kec_code = (dom_area6_code.presence || area6_code)

    # Validasi semua kode harus ada
    raise ActiveRecord::RecordInvalid, "Kode wilayah tidak lengkap" if prov_code.blank? || kota_code.blank? || kec_code.blank?

    # Format AABBCC dari kode wilayah
    # AA = 2 digit provinsi, BB = 2 digit kota (digit 3-4), CC = 2 digit kecamatan (digit 5-6)
    aa = prov_code[-2..-1]  # 2 digit terakhir provinsi
    bb = kota_code[-2..-1]  # 2 digit terakhir kota
    cc = kec_code[-2..-1]   # 2 digit terakhir kecamatan

    prefix = "#{aa}#{bb}#{cc}"

    Member.transaction do
      # Cari atau buat sequence untuk prefix ini
      seq = KtaSequence.lock.find_by(area6_code: prefix) || KtaSequence.create!(area6_code: prefix, last_value: 0)
      seq.last_value += 1
      seq.save!

      # Format: AABBCCYYYYYY (12 digit tanpa titik untuk database)
      # Untuk tampilan, gunakan helper kta_number_formatted
      self.kta_number = sprintf("%s%06d", prefix, seq.last_value)
    end
  end

  # Helper untuk format KTA dengan titik untuk tampilan
  # Contoh: 320101000001 -> NAGR: 320101.000001
  def kta_number_formatted
    return nil unless kta_number
    if kta_number.length == 12
      "NAGR: #{kta_number[0..5]}.#{kta_number[6..11]}"
    else
      "NAGR: #{kta_number}" # fallback jika format tidak sesuai
    end
  end

  def assign_membership_letter_number
    today = Time.zone.today
    self.letter_month ||= today.month
    self.letter_year ||= today.year
    Member.transaction do
      relation = Member.lock.where(letter_month: letter_month, letter_year: letter_year)
      self.letter_sequence ||= relation.maximum(:letter_sequence).to_i + 1
    end
  end

  def letter_number
    return unless letter_sequence && letter_month && letter_year
    seq = format("%03d", letter_sequence)
    roman = self.class.month_to_roman(letter_month)
    [seq, "DPP-GERAK", "NAGR", roman, letter_year].compact.join("/")
  end

  def nagr_number
    value = kta_number.to_s
    return if value.blank?
    pref = value[0, 6]
    seq = value[-6, 6] || value[6..]&.rjust(6, "0")
    "NAGR.#{pref}.#{seq}"
  end

  def dpw_name
    find_wilayah_name(effective_area2_code)
  end

  def dpd_name
    find_wilayah_name(effective_area4_code)
  end

  def dpc_name
    find_wilayah_name(effective_area6_code)
  end

  def letter_date
    (created_at&.in_time_zone || Time.zone.now).to_date
  end

  def self.month_to_roman(month)
    idx = month.to_i - 1
    return if idx.negative? || idx > 11
    %w[I II III IV V VI VII VIII IX X XI XII][idx]
  end

  private

  def effective_area6_code
    dom_area6_code.presence || area6_code
  end

  def effective_area4_code
    dom_area4_code.presence || area4_code || effective_area6_code&.first(4)
  end

  def effective_area2_code
    dom_area2_code.presence || area2_code || effective_area6_code&.first(2)
  end

  def find_wilayah_name(code)
    return if code.blank?
    Wilayah.find_by(code_norm: code)&.name || code
  end

  def self.find_by_nik_plain(nik_plain)
    # Karena NIK di-encrypt, kita gunakan fingerprint untuk mencari
    nik_clean = nik_plain.to_s.gsub(/\D/, "")
    nik_hash = Digest::SHA256.hexdigest(nik_clean)
    where(nik_fingerprint: nik_hash).first
  end

  def self.find_by_credentials(nik_plain, phone_plain)
    # Karena NIK dan Phone di-encrypt, kita gunakan fingerprint untuk mencari
    nik_clean = nik_plain.to_s.gsub(/\D/, "")
    phone_clean = phone_plain.to_s.gsub(/\D/, "")

    nik_hash = Digest::SHA256.hexdigest(nik_clean)
    phone_hash = Digest::SHA256.hexdigest(phone_clean)

    where(nik_fingerprint: nik_hash, phone_fingerprint: phone_hash).first
  end
end
