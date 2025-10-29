# app/controllers/members_controller.rb
require "stringio"
require "prawn/table"

class MembersController < ApplicationController
  before_action :require_login, except: [:letter, :sk]
  before_action :set_member, only: [:show, :kta, :sk]

  def show
    # @member is set by before_action :set_member using public_id
  end

  def kta
    @member = Member.find_by!(public_id: params[:id])
    respond_to do |format|
      format.pdf do
        unless @member.kta_pdf.attached?
          @member.attach_kta_pdf!
        end

        data = @member.kta_pdf.attached? ? @member.kta_pdf.download : @member.build_kta_pdf
        send_data data,
                  filename: "kta-#{@member.kta_number}.pdf",
                  type: "application/pdf",
                  disposition: "inline"
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
        pdf.text "Nomor : #{@member.letter_number || "-"}", align: :center

        pdf.move_down 20
        pdf.text "Bersama ini kami menerangkan bahwa dibawah ini:", leading: 4
        pdf.move_down 10

        details = [
          ["Nama", @member.name],
          ["NAGR", @member.nagr_number.presence || "-"],
          ["DPC", @member.dpc_name.presence || "-"],
          ["DPD", @member.dpd_name.presence || "-"],
          ["DPW", @member.dpw_name.presence || "-"],
        ]

        pdf.table(details, cell_style: { borders: [], padding: [6, 4, 6, 4] }, column_widths: [100, 360])

        pdf.move_down 20
        pdf.text "Demikian surat keterangan ini dibuat untuk digunakan sebagaimana mestinya.", leading: 4
        pdf.move_down 40
        pdf.text "Jakarta, #{@member.letter_date.strftime("%d %B %Y")}", align: :right
        pdf.text "Dewan Pimpinan Pusat Gerakan Rakyat", align: :right
        pdf.move_down 60
        pdf.text "_____________________________", align: :right
        pdf.text "Ketua Umum", align: :right

        send_data pdf.render,
                  filename: "surat-anggota-#{@member.kta_number}.pdf",
                  type: "application/pdf",
                  disposition: "inline"
      end
    end
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    head :not_found
  end

  def sk
    @member = Member.find_by!(public_id: params[:id])
    respond_to do |format|
      format.pdf do
        unless @member.sk_pdf.attached?
          @member.attach_sk_pdf!
        end

        data = @member.sk_pdf.attached? ? @member.sk_pdf.download : @member.build_sk_pdf
        send_data data,
                  filename: "sk-#{@member.kta_number}.pdf",
                  type: "application/pdf",
                  disposition: "inline"
      end
    end
  end

  private

  def set_member
    # Use public_id-friendly URLs (Member#to_param returns public_id)
    @member = Member.find_by!(public_id: params[:id])
  end

  def member_region_names(member)
    prov = member.dom_area2_code.presence || member.area2_code
    reg = member.dom_area4_code.presence || member.area4_code
    dis = member.dom_area6_code.presence || member.area6_code
    dpw = Wilayah.find_by(level: Wilayah::LEVEL_PROV, code_norm: prov)&.name.to_s
    dpd = Wilayah.find_by(level: Wilayah::LEVEL_REG, code_norm: reg)&.name.to_s
    dpc = Wilayah.find_by(level: Wilayah::LEVEL_DIS, code_norm: dis)&.name.to_s
    [dpw, dpd, dpc]
  end
end
