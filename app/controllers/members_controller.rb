# app/controllers/members_controller.rb
class MembersController < ApplicationController
  before_action :require_login

  def show
    @member = Member.find(params[:id])
  end

  def kta
    @member = Member.find(params[:id])
    respond_to do |format|
      format.pdf do
        pdf = Prawn::Document.new(page_size: "A7", page_layout: :landscape)
        pdf.text "KARTU TANDA ANGGOTA", style: :bold, size: 14, align: :center
        pdf.move_down 10
        pdf.text "Nama: #{@member.name}"
        pdf.text "No. KTA: #{@member.kta_number}"
        pdf.text "NIK: #{@member.nik.gsub(/\d(?=\d{4})/, "•")}"
        pdf.text "Wilayah: #{@member.area6_code}"
        send_data pdf.render, filename: "kta-#{@member.kta_number}.pdf", type: "application/pdf", disposition: "inline"
      end
    end
  end
end
