class RequireEventAttributes < ActiveRecord::Migration[8.0]
  def change
    change_column_null :events, :name, false
    change_column_null :events, :slug, false
    change_column_null :events, :public_token, false
  end
end
