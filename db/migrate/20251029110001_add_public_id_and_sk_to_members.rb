class AddPublicIdAndSkToMembers < ActiveRecord::Migration[8.0]
  def change
    add_column :members, :public_id, :string
    add_column :members, :sk_number, :string
    add_index :members, :public_id, unique: true
    add_index :members, :sk_number, unique: true
  end
end
