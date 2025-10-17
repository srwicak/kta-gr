# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

sql_path = Rails.root.join("db", "wilayah.sql")
raise "File tidak ditemukan: #{sql_path}" unless File.exist?(sql_path)
rows = []
File.read(sql_path).scan(/\('([^']+)'\s*,\s*'([^']+)'\)/).each do |code_dot, name|
  code_norm = code_dot.delete(".")
  level = code_dot.split(".").size
  parent = case level
    when 1 then nil
    when 2 then code_dot.split(".")[0]
    when 3 then code_dot.split(".")[0, 2].join(".")
    else code_dot.split(".")[0, 3].join(".")
    end
  rows << {
    code_dotted: code_dot,
    code_norm: code_norm,
    level: level,
    name: name,
    parent_code_norm: parent&.delete("."),
  }
end
Wilayah.insert_all(rows, unique_by: :code_norm)
puts "Seed wilayah selesai: #{rows.size} baris"
