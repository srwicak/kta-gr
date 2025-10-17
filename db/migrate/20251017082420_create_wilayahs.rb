class CreateWilayahs < ActiveRecord::Migration[8.0]
  def change
    create_table :wilayahs do |t|
      t.string :code_dotted, null: false # "11.01.01"
      t.string :code_norm, null: false # "110101"
      t.integer :level, null: false # 1=prov,2=kab/kota,3=kec,4=desa/kel
      t.string :name, null: false
      t.string :parent_code_norm # prefix parent ("11","1101","110101")
      t.timestamps
    end
  add_index :wilayahs, :code_norm, unique: true
  add_index :wilayahs, :parent_code_norm
  add_index :wilayahs, [:level, :code_norm]
  end
end