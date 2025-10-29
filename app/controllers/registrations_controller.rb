# app/controllers/registrations_controller.rb
class RegistrationsController < ApplicationController
  def new
    @member = Member.new
  end

  def create
    @member = Member.new(member_params)

    if @member.save
      redirect_to success_registration_path(@member)
    else
      flash.now[:alert] = @member.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  def success
    @member = Member.find_by!(public_id: params[:id])
  end

  private

  def member_params
    params.require(:member).permit(
      :name, :phone, :nik, :ktp_photo, :selfie_photo,
      :dom_area2_code, :dom_area4_code, :dom_area6_code, :dom_area10_code, :dom_address
    )
  end
end
