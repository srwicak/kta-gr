class AddUniqueIndexToMembersPhone < ActiveRecord::Migration[8.0]
  def change
    add_index :members, :phone, unique: true
  end
end
