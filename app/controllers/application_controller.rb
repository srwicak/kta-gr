class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  helper_method :current_member, :logged_in?

  private

  def current_member
    @current_member ||= Member.find_by(id: session[:member_id]) if session[:member_id]
  end

  def logged_in?
    current_member.present?
  end

  def require_login
    unless logged_in?
      flash[:alert] = "Anda harus login terlebih dahulu"
      redirect_to new_session_path
    end
  end
end
