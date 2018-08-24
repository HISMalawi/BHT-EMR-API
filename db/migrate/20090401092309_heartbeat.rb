class Heartbeat < ActiveRecord::Migration[5.2]
  def self.up
    create_table :heart_beat, id: false do |t|
      t.integer :id, null: false
      t.column  :ip, :string, limit: 20
      t.column  :property, :string, limit: 200
      t.column  :value, :string, limit: 200
      t.column  :time_stamp, :datetime
      t.column  :username, :string, limit: 10
      t.column  :url, :string, limit: 100
    end
    execute "ALTER TABLE `heart_beat` CHANGE COLUMN `id` `id` INT(11) NOT NULL AUTO_INCREMENT , ADD PRIMARY KEY (`id`);"
  end

  def self.down
    drop_table :heart_beat
  end
end
