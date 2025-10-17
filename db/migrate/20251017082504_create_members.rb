class CreateMembers < ActiveRecord::Migration[8.0]
  def change
    create_table :members do |t|
      t.string :name, null: false
      t.string :nik, null: false # encrypted (deterministic) for lookups
      t.string :phone, null: false # encrypted


      t.string :nik_fingerprint, null: false # SHA256 of NIK (audit/dedupe)


      t.date :birthdate
      t.string :gender


      t.string :area2_code # 2d prov from NIK
      t.string :area4_code # 4d reg from NIK
      t.string :area6_code # 6d dis from NIK
      t.string :dom_area2_code
      t.string :dom_area4_code
      t.string :dom_area6_code


      t.string :kta_number, index: { unique: true }
      t.string :password_digest


      t.timestamps
    end
  add_index :members, :nik, unique: true
  add_index :members, :nik_fingerprint, unique: true
  end
end