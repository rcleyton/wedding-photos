class CreatePhotos < ActiveRecord::Migration[8.0]
  def change
    create_table :photos do |t|
      t.references :event, null: false, foreign_key: true
      t.string :guest_name
      t.integer :status, null: false, default: 0

      t.timestamps
    end
  end
end
