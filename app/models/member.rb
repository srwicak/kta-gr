class Member < ApplicationRecord
  # Active Record Encryption
  encrypts :name
  encrypts :phone
  encrypts :nik, deterministic: true, downcase: true

  has_secure_password validations: false
  has_one_attached :ktp_photo
  has_one_attached :selfie_photo

  validates :name, :nik, :phone, presence: true

  before_validation :set_defaults_from_nik, on: :create
  before_validation :set_initial_password_from_phone, on: :create
  before_create :assign_kta_number

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
  end

  def set_initial_password_from_phone
    self.password = phone if password_digest.blank? && phone.present?
  end

  def assign_kta_number
    pref6 = (dom_area6_code.presence || area6_code)
    raise ActiveRecord::RecordInvalid, "area6_code kosong" if pref6.blank?
    Member.transaction do
      seq = KtaSequence.lock.find_by(area6_code: pref6) || KtaSequence.create!(area6_code: pref6, last_value: 0)
      seq.last_value += 1
      seq.save!
      self.kta_number = sprintf("%s%010d", pref6, seq.last_value)
    end
  end

  def self.find_by_nik_plain(nik_plain)
    where(nik: nik_plain).first
  end
end
