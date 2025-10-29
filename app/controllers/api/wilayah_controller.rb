# app/controllers/api/wilayah_controller.rb
class Api::WilayahController < ApplicationController
  def children
    parent = params[:parent].to_s
    level = params[:level].to_i
    scope = case level
      when 2 then Wilayah.where(level: 2, parent_code_norm: parent)
      when 3 then Wilayah.where(level: 3, parent_code_norm: parent)
      when 4 then Wilayah.where(level: 4, parent_code_norm: parent)
      else Wilayah.none
      end
    render json: scope.order(:code_norm).pluck(:code_norm, :name).map { |c, n| { code: c, name: n } }
  end
end
