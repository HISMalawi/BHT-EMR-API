# frozen_string_literal: true

# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
Encounter.where(uuid: nil, voided: [0, 1]).each do |encounter|
  encounter.uuid = SecureRandom.uuid
  encounter.save
end

# get all obs with uuid whether voided or not
Observation.where(uuid: nil, voided: [0, 1]).each do |ob|
  ob.uuid = SecureRandom.uuid
  ob.save
end

# execute alter table and have uuid as not null and unique
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE encounter MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

# execute alter table and have uuid as not null and unique
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE obs MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL