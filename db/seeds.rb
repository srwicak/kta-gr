# Seed data Wilayah dari file SQL (robust terhadap apostrof ganda dan ukuran besar)
sql_path = Rails.root.join("db", "wilayah.sql")
if File.exist?(sql_path)
  total = 0
  batch = []
  batch_size = 1000

  # Regex untuk menangkap tuple ('kode','nama') dengan dukungan apostrof ganda ('')
  tuple_regex = /\('((?:[^']|'{2})+?)'\s*,\s*'((?:[^']|'{2})+?)'\)/

  File.foreach(sql_path) do |line|
    line.scan(tuple_regex) do |code_dot_raw, name_raw|
      code_dot = code_dot_raw.gsub("''", "'")
      name = name_raw.gsub("''", "'")

      code_norm = code_dot.delete(".")
      level = code_dot.count(".") + 1
      parent_dotted = case level
        when 1 then nil
        when 2 then code_dot.split(".")[0]
        when 3 then code_dot.split(".")[0, 2].join(".")
        else code_dot.split(".")[0, 3].join(".")
        end

      batch << {
        code_dotted: code_dot,
        code_norm: code_norm,
        level: level,
        name: name,
        parent_code_norm: parent_dotted&.delete("."),
      }

      if batch.length >= batch_size
        Wilayah.insert_all(batch, unique_by: :code_norm)
        total += batch.length
        batch.clear
      end
    end
  end

  if batch.any?
    Wilayah.insert_all(batch, unique_by: :code_norm)
    total += batch.length
  end
  puts "Seed wilayah selesai: #{total} baris"
else
  puts "Lewati seed wilayah: file tidak ditemukan di #{sql_path}"
end
