# app/controllers/sessions_controller.rb
class SessionsController < ApplicationController
  def new; end

  def create
    member = Member.find_by_nik_plain(params[:nik])
    if member&.authenticate(params[:phone])
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
