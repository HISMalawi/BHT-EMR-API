class AddUserRecordType < ActiveRecord::Migration[5.2]
  def up
    RecordType.create(name: User.to_s)
  end

  def down
    RecordType.find_by_name(User.to_s).&destroy
  end
end
