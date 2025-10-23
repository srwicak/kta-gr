class UpdateExistingKtaNumbers < ActiveRecord::Migration[8.0]
  def up
    # Update KTA yang ada titiknya jadi tanpa titik
    # Contoh: 320101.000001 -> 320101000001
    Member.where("kta_number LIKE ?", "%.%").find_each do |member|
      new_kta = member.kta_number.gsub(".", "")
      member.update_column(:kta_number, new_kta)
    end
  end

  def down
    # Rollback: tambah titik kembali
    # Contoh: 320101000001 -> 320101.000001
    Member.where("LENGTH(kta_number) = ?", 12).find_each do |member|
      kta = member.kta_number
      new_kta = "#{kta[0..5]}.#{kta[6..11]}"
      member.update_column(:kta_number, new_kta)
    end
  end
end
