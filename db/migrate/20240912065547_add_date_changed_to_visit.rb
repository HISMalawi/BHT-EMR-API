class AddDateChangedToVisit < ActiveRecord::Migration[7.0]
  def change
    add_column :visit, :date_changed, :datetime
  end
end
