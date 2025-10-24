class AddLetterFieldsToMembers < ActiveRecord::Migration[8.0]
  def change
    add_column :members, :letter_sequence, :integer
    add_column :members, :letter_month, :integer
    add_column :members, :letter_year, :integer

    add_index :members, [:letter_year, :letter_month, :letter_sequence], unique: true
  end
end
