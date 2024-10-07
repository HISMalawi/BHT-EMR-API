class ChangeDateStoppedToBeNullOnVisitTable < ActiveRecord::Migration[7.0]
  def change
    change_column_null :visits, :closedDateTime, true
  end
end
