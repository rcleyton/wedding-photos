class CreateEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :events do |t|
      t.string :name
      t.string :slug
      t.string :public_token, null: false
      t.date :event_date

      t.timestamps
    end

    add_index :events, :slug, unique: true
    add_index :events, :public_token, unique: true
  end
end
