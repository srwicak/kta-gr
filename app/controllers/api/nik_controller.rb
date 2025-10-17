# app/controllers/api/nik_controller.rb
class Api::NikController < ApplicationController
  def show
    nik = params[:nik].to_s.gsub(/\D/, "")
    return render json: { error: "NIK minimal 6 digit" }, status: :unprocessable_entity if nik.length < 6

    h = { prov: nik[0, 2], reg: nik[0, 4], dis: nik[0, 6] }
    prov = Wilayah.find_by(code_norm: h[:prov])
    reg = Wilayah.find_by(code_norm: h[:reg])
    dis = Wilayah.find_by(code_norm: h[:dis])

    dd = nik[6, 2].to_i; mm = nik[8, 2].to_i; yy = nik[10, 2].to_i
    female = dd >= 40; day = female ? dd - 40 : dd
    cur = Date.current.year % 100
    year = (yy <= cur ? 2000 + yy : 1900 + yy)
    birth_ok = Date.valid_date?(year, mm, day)

    render json: {
             province: prov&.slice(:code_norm, :name),
             regency: reg&.slice(:code_norm, :name),
             district: dis&.slice(:code_norm, :name),
             birthdate: (birth_ok ? Date.new(year, mm, day).iso8601 : nil),
             gender: (birth_ok ? (female ? "Perempuan" : "Laki-laki") : nil),
           }
  end
end
