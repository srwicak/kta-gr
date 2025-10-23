# app/controllers/sessions_controller.rb
class SessionsController < ApplicationController
  def new; end

  def create
    # Cari member berdasarkan NIK dan Phone fingerprint
    member = Member.find_by_credentials(params[:nik], params[:phone])

    # Normalize phone number untuk authenticate
    phone_input = params[:phone].to_s.gsub(/\D/, "")

    if member&.authenticate(phone_input)
      session[:member_id] = member.id
      redirect_to member_path(member)
    else
      flash.now[:alert] = "Login gagal. NIK atau No. HP tidak sesuai."
      render :new, status: :unauthorized
    end
  end

  def destroy
    reset_session
    redirect_to root_path
  end
end
