class AddPhoneFingerprintToMembers < ActiveRecord::Migration[8.0]
  def change
    add_column :members, :phone_fingerprint, :string
    add_index :members, :phone_fingerprint, unique: true
  end
end
