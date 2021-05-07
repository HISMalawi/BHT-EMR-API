# This migration comes from lab (originally 20210126092910)
class CreateLabLabAccessionNumberCounters < ActiveRecord::Migration[5.2]
  def change
    return if table_exists?(:lab_accession_number_counters)

    create_table :lab_accession_number_counters do |t|
      t.date :date
      t.bigint :value

      t.timestamps
    end

    unless index_exists?(:lab_accession_number_counters, :date, unique: true)
      add_index :lab_accession_number_counters, %i[date], unique: true
    end
  end
end
