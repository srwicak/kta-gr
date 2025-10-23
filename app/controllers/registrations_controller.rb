# app/controllers/registrations_controller.rb
class RegistrationsController < ApplicationController
  def new
    @member = Member.new
  end

  def create
    @member = Member.new(member_params)

    # Jika domisili berbeda, gunakan yang diinput user
    # Jika tidak dicentang, gunakan dari KTP (area*_code dari NIK)
    if params[:member][:domicile_diff] == "1"
      @member.dom_area2_code = params[:member][:dom_area2_code]
      @member.dom_area4_code = params[:member][:dom_area4_code]
      @member.dom_area6_code = params[:member][:dom_area6_code]
    else
      # Jika domisili sama dengan KTP, copy dari area*_code
      # area*_code sudah diisi otomatis dari NIK di callback set_defaults_from_nik
      @member.dom_area2_code = @member.area2_code
      @member.dom_area4_code = @member.area4_code
      @member.dom_area6_code = @member.area6_code
    end

    if @member.save
      redirect_to success_registration_path(@member)
    else
      flash.now[:alert] = @member.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  def success
    @member = Member.find(params[:id])
  end

  private

  def member_params
    params.require(:member).permit(
      :name, :phone, :nik, :ktp_photo, :selfie_photo,
      :dom_area2_code, :dom_area4_code, :dom_area6_code
    )
  end
end
