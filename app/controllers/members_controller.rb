# app/controllers/members_controller.rb
require "stringio"
require "prawn/table"

class MembersController < ApplicationController
  before_action :require_login, except: :letter
  before_action :set_member, only: [:show, :kta]

  def show
  end

  def kta
    respond_to do |format|
      format.pdf do
        pdf = Prawn::Document.new(page_size: "A7", page_layout: :landscape)
        pdf.font_size 10
        pdf.text "KARTU TANDA ANGGOTA", style: :bold, size: 14, align: :center
        pdf.move_down 10
        pdf.text "Nama: #{@member.name}"
        pdf.text "No. KTA: #{@member.kta_number}"
        masked_nik = @member.nik.to_s.gsub(/\d(?=\d{4})/, "•")
        pdf.text "NIK: #{masked_nik}"
        area_code = @member.dom_area6_code.presence || @member.area6_code
        pdf.text "Wilayah: #{area_code}"

        token = @member.signed_id(purpose: :membership_letter)
        letter_path = letter_member_path(@member, format: :pdf, token: token)
        letter_url = "#{request.base_url}#{letter_path}"
        qrcode = RQRCode::QRCode.new(letter_url)
        png = qrcode.as_png(size: 200)
        pdf.move_down 10
        pdf.image StringIO.new(png.to_s), width: 70, position: :right
        pdf.move_down 5
        pdf.text "Pindai QR untuk verifikasi surat anggota", size: 8, align: :right

        send_data pdf.render, filename: "kta-#{@member.kta_number}.pdf", type: "application/pdf", disposition: "inline"
      end
    end
  end

  def letter
    token = params[:token]
    return head :not_found if token.blank?

    @member = Member.find_signed!(token, purpose: :membership_letter)
    respond_to do |format|
      format.pdf do
        pdf = Prawn::Document.new(page_size: "A4")
        pdf.font "Helvetica"
        pdf.text "GERAKAN RAKYAT", align: :center, style: :bold, size: 18
        pdf.text "Dewan Pimpinan Pusat", align: :center, size: 12
        pdf.move_down 12
        pdf.stroke_horizontal_rule
        pdf.move_down 18
        pdf.text "SURAT KETERANGAN ANGGOTA GERAKAN RAKYAT", style: :bold, size: 14, align: :center
        pdf.move_down 5
        pdf.text "Nomor : #{@member.letter_number || '-'}", align: :center

        pdf.move_down 20
        pdf.text "Bersama ini kami menerangkan bahwa dibawah ini:", leading: 4
        pdf.move_down 10

        details = [
          ["Nama", @member.name],
          ["NAGR", @member.nagr_number.presence || "-"],
          ["DPC", @member.dpc_name.presence || "-"],
          ["DPD", @member.dpd_name.presence || "-"],
          ["DPW", @member.dpw_name.presence || "-"]
        ]

        pdf.table(details, cell_style: { borders: [], padding: [6, 4, 6, 4] }, column_widths: [100, 360])

        pdf.move_down 20
        pdf.text "Demikian surat keterangan ini dibuat untuk digunakan sebagaimana mestinya.", leading: 4

        pdf.move_down 40
        pdf.text "Jakarta, #{@member.letter_date.strftime('%d %B %Y')}", align: :right
        pdf.text "Dewan Pimpinan Pusat Gerakan Rakyat", align: :right

        pdf.move_down 60
        pdf.text "_____________________________", align: :right
        pdf.text "Ketua Umum", align: :right

        send_data pdf.render, filename: "surat-anggota-#{@member.kta_number}.pdf", type: "application/pdf", disposition: "inline"
      end
    end
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    head :not_found
  end

  private

  def set_member
    @member = Member.find(params[:id])
  end
end
