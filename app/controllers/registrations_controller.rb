# app/controllers/registrations_controller.rb
class RegistrationsController < ApplicationController
  def new
    @member = Member.new
  end

  def create
    @member = Member.new(member_params)
    if params[:member][:domicile_diff] == "1"
      @member.dom_area2_code = params[:member][:dom_area2_code]
      @member.dom_area4_code = params[:member][:dom_area4_code]
      @member.dom_area6_code = params[:member][:dom_area6_code]
    end
    if @member.save
      redirect_to @member, notice: "Pendaftaran berhasil. Nomor KTA telah dibuat."
    else
      flash.now[:alert] = @member.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  private

  def member_params
    params.require(:member).permit(:name, :phone, :nik, :ktp_photo, :selfie_photo)
  end
end
