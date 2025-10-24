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
    where(nik: nik_plain).first
  end
end
