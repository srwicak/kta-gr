class Member < ApplicationRecord
  # Active Record Encryption
  encrypts :name
  encrypts :phone, deterministic: true
  encrypts :nik, deterministic: true, downcase: true
  encrypts :kta_number, deterministic: true, downcase: true

  has_secure_password validations: false
  has_one_attached :ktp_photo
  has_one_attached :selfie_photo
  has_one_attached :sk_pdf
  has_one_attached :kta_pdf

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
  before_create :assign_public_id
  before_create :assign_kta_number

  before_create :assign_membership_letter_number

  before_create :assign_sk_number
  after_commit :ensure_pdfs_attached, on: :create


  def set_defaults_from_nik
    s = nik.to_s.gsub(/\D/, "")
    return if s.length < 12
    self.area2_code ||= s[0, 2]
    self.area4_code ||= s[0, 4]
    self.area6_code ||= s[0, 6]

    # Prefill domisili (dropdown) dengan hasil parsing NIK jika belum diisi user
    self.dom_area2_code ||= self.area2_code
    self.dom_area4_code ||= self.area4_code
    self.dom_area6_code ||= self.area6_code

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
    # Wajib: alamat domisili (menggunakan dropdown) minimal Prov/Kota/Kec dan alamat teks
    if dom_area2_code.blank? || dom_area4_code.blank? || dom_area6_code.blank?
      errors.add(:base, "Alamat domisili harus diisi lengkap (Provinsi, Kota, Kecamatan)")
    end
    if dom_address.blank?
      errors.add(:dom_address, "harus diisi")
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

  def assign_public_id
    self.public_id ||= Nanoid.generate(size: 12)
  end

  def assign_sk_number
    now = Time.current
    period = now.strftime("%Y%m") # YYYYMM
    roman_month = Member.roman_month(now.month)
    year = now.year

    # NAGR segment uses dotted AABBCC.XXXXXX as per request
    aabbcc = kta_number.to_s[0, 6]
    xxxxxx = kta_number.to_s[6, 6]
    nagr_segment = ["NAGR", aabbcc, xxxxxx].join(".")

    Member.transaction do
      seq = LetterSequence.lock.find_or_create_by!(period: period) do |s|
        s.last_value = 0
      end
      seq.last_value += 1
      seq.save!

      self.sk_number = sprintf("%03d/DPP-GERAK/%s/%s/%04d", seq.last_value, nagr_segment, roman_month, year)
    end
  end

  def self.roman_month(m)
    %w[ I II III IV V VI VII VIII IX X XI XII ][m - 1]
  end

  def to_param
    public_id.presence || super
  end

  # Helper untuk format KTA dengan titik untuk tampilan
  # Contoh: 320101000001 -> NAGR: 320101.000001
  def kta_number_formatted
    return nil unless kta_number
    # Diminta tanpa titik untuk tampilan umum
    value = kta_number.to_s
    return if value.blank?
    pref = value[0, 6]
    seq = value[-6, 6] || value[6..]&.rjust(6, "0")
    "#{pref}.#{seq}"
  end

  # --- PDF generation and attachments ---
  def ensure_pdfs_attached
    attach_sk_pdf! unless sk_pdf.attached?
    attach_kta_pdf! unless kta_pdf.attached?
  rescue => e
    Rails.logger.error("PDF attach failed: #{e.class} #{e.message}")
  end

  def attach_sk_pdf!
    pdf = build_sk_pdf
    sk_pdf.attach(io: StringIO.new(pdf), filename: "sk-#{public_id}.pdf", content_type: "application/pdf")
  end

  def attach_kta_pdf!
    pdf = build_kta_pdf
    kta_pdf.attach(io: StringIO.new(pdf), filename: "kta-#{kta_number}.pdf", content_type: "application/pdf")
  end

  def build_kta_pdf
    require "prawn"
    require "rqrcode"

    # CR80 ID card portrait size (54mm x 86mm) in points (1pt = 1/72 inch, 1 inch = 25.4mm)
    page_w = (54.0 * 72.0 / 25.4).round(2)   # ~153.07pt
    page_h = (86.0 * 72.0 / 25.4).round(2)   # ~243.78pt

    pdf = Prawn::Document.new(page_size: [page_w, page_h], page_layout: :portrait, margin: 0)

    # Background template front (overlay on this page only)
    template_front = Rails.root.join("app/assets/images/kta/front.jpg")
    if File.exist?(template_front)
      pdf.canvas do
        # fit preserves aspect ratio within the given box
        pdf.image template_front.to_s, at: [0, page_h], fit: [page_w, page_h]
      end
    end

    # Small helper for text placement with auto-shrink
    text_at = lambda do |txt, x:, y:, width:, size:, align: :left, color: "000000", style: nil, leading: 0, uppercase: false|
      s = txt.to_s
      s = s.upcase if uppercase
      pdf.fill_color color
      pdf.font_size size
      pdf.font(pdf.font.name, style: style) if style
      pdf.text_box s,
                   at: [x, y],
                   width: width,
                   height: size * 1.5 + leading,
                   overflow: :shrink_to_fit,
                   min_font_size: 6,
                   align: align,
                   leading: leading
    end

    padding = 10

    # Data fields
    aabbcc = kta_number.to_s[0, 6]
    xxxxxx = kta_number.to_s[6, 6]
    nagr_display = ["NAGR:", kta_number_formatted.presence || [aabbcc, xxxxxx].join(".")].join(" ")

    dpw_name, dpd_name, _dpc = Member.member_region_names_for(self)
    kota_prov = [dpd_name, dpw_name].reject(&:blank?).join(" - ")
    bulan_tahun = I18n.l((created_at || Time.current).to_date, format: "%B %Y")

    # Suggested placements (adjust to match your front.jpg design)
    content_w = page_w - (padding * 2)

    # Vertical flow from top to bottom:
    y = page_h - 20

    # 1) NAGR (centered, smaller font)
    y -= 2
    text_at.call(nagr_display, x: padding, y: y, width: content_w, size: 8, align: :center, color: "222222")
    y -= 14

    # 2) Foto selfie (centered, 80% of previous 60x80 -> 48x64)
    if selfie_photo.attached?
      begin
        img_io = StringIO.new(selfie_photo.download)
        selfie_w = 48.0
        selfie_h = 64.0
        selfie_x = (page_w - selfie_w) / 2.0
        selfie_y = y
        pdf.image img_io, at: [selfie_x, selfie_y], width: selfie_w, height: selfie_h
        # optional border
        pdf.stroke_color "ffffff"
        pdf.line_width 0.5
        pdf.stroke_rectangle [selfie_x, selfie_y], selfie_w, selfie_h
      rescue => e
        Rails.logger.warn("Failed to place selfie on KTA: #{e.class} #{e.message}")
      ensure
        y -= (selfie_h + 10)
      end
    else
      y -= 22
    end

    # 3) Nama (centered, uppercase, smaller)
    text_at.call(name, x: padding, y: y, width: content_w, size: 9, align: :center, color: "111111", style: :bold, uppercase: true)
    y -= 16

    # 4) Kota - Provinsi (centered)
    text_at.call(kota_prov, x: padding, y: y, width: content_w, size: 7.5, align: :center, color: "333333")
    y -= 14

    # 5) Bulan/Tahun (nama bulan, bukan angka saja)
    text_at.call(bulan_tahun, x: padding, y: y, width: content_w, size: 7, align: :center, color: "444444")

    # QR code (bottom-right), 50% of previous (60 -> 30)
    begin
      verify_url = url_helpers.sk_member_url(self, format: :pdf, host: default_host)
      qrcode = RQRCode::QRCode.new(verify_url)
      png = qrcode.as_png(size: 300, border_modules: 0)
      qr_size = 30.0
      qr_x = page_w - padding - qr_size
      qr_y = padding + qr_size # because 'at' expects top-left; bottom margin = padding
      pdf.image StringIO.new(png.to_s), at: [qr_x, qr_y], width: qr_size, height: qr_size
    rescue => e
      Rails.logger.warn("Failed to place QR on KTA: #{e.class} #{e.message}")
    end

    # Page 2: back side (no overlays)
    template_back = Rails.root.join("app/assets/images/kta/back.jpg")
    pdf.start_new_page
    if File.exist?(template_back)
      pdf.canvas do
        pdf.image template_back.to_s, at: [0, page_h], fit: [page_w, page_h]
      end
    end

    pdf.render
  end

  def build_sk_pdf
    require "prawn"
    require "rqrcode"
    pdf = Prawn::Document.new(page_size: "A4")
    pdf.font_size 12
    pdf.text "KOP SURAT", align: :center, style: :bold
    pdf.move_down 4
    pdf.text "SURAT KETERANGAN ANGGOTA GERAKAN RAKYAT", align: :center, style: :bold
    pdf.move_down 4
    pdf.text "Nomor: #{sk_number}", align: :center
    pdf.move_down 16
    pdf.text "Bersama ini kami menerangkan bahwa dibawah ini:", align: :left
    pdf.move_down 8

    aabbcc = kta_number.to_s[0, 6]
    xxxxxx = kta_number.to_s[6, 6]
    nagr = ["NAGR", aabbcc, xxxxxx].join(".")
    dpw_name, dpd_name, dpc_name = Member.member_region_names_for(self)

    rows = [
      ["Nama", ":", name.to_s],
      ["NAGR", ":", nagr],
      ["DPC", ":", dpc_name],
      ["DPD", ":", dpd_name],
      ["DPW", ":", dpw_name],
    ]
    rows.each { |label, sep, val| pdf.text "#{label.ljust(14)} #{sep} #{val}" }

    pdf.move_down 20
    sk_url = url_helpers.sk_member_url(self, format: :pdf, host: default_host)
    qrcode = RQRCode::QRCode.new(sk_url)
    png = qrcode.as_png(size: 220)
    pdf.text "Pindai QR untuk verifikasi:", size: 10
    pdf.image StringIO.new(png.to_s), width: 120, at: [pdf.bounds.left, pdf.cursor - 10]

    pdf.move_down 140
    pdf.text "Ditetapkan di: Jakarta", size: 10
    pdf.text "Tanggal: #{I18n.l(Date.current)}", size: 10
    pdf.render
  end

  def default_host
    Rails.application.routes.default_url_options[:host] || ENV["APP_HOST"] || ENV["RAILS_HOST"] || "http://localhost:3000"
  end

  def url_helpers
    Rails.application.routes.url_helpers
  end

  def self.member_region_names_for(member)
    prov = member.dom_area2_code.presence || member.area2_code
    reg = member.dom_area4_code.presence || member.area4_code
    dis = member.dom_area6_code.presence || member.area6_code
    dpw = Wilayah.find_by(level: Wilayah::LEVEL_PROV, code_norm: prov)&.name.to_s
    dpd = Wilayah.find_by(level: Wilayah::LEVEL_REG, code_norm: reg)&.name.to_s
    dpc = Wilayah.find_by(level: Wilayah::LEVEL_DIS, code_norm: dis)&.name.to_s
    [dpw, dpd, dpc]
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
