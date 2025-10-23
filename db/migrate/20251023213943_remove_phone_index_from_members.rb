class RemovePhoneIndexFromMembers < ActiveRecord::Migration[8.0]
  def change
    remove_index :members, :phone if index_exists?(:members, :phone)
  end
end
