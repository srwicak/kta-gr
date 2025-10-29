class CreateLetterSequences < ActiveRecord::Migration[8.0]
  def change
    create_table :letter_sequences, id: false do |t|
      t.string :period, null: false, primary_key: true # YYYYMM
      t.integer :last_value, null: false, default: 0
      t.timestamps
    end
  end
end
