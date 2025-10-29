class AddKelurahanAndAddressToMembers < ActiveRecord::Migration[8.0]
  def change
    add_column :members, :dom_area10_code, :string # 10d village/kelurahan code (optional)
    add_column :members, :dom_address, :text # alamat lengkap domisili

    add_index :members, :dom_area10_code
  end
end
