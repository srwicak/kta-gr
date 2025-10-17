class CreateKtaSequences < ActiveRecord::Migration[8.0]
  def change
    create_table :kta_sequences, id: false do |t|
      t.string :area6_code, null: false, primary_key: true
      t.integer :last_value, null: false, default: 0
      t.timestamps
    end
  end
end