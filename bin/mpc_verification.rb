# frozen_string_literal: true

require 'roo'

# method to get the clients from POC cohort
def fetch_poc_clients
  @poc = ActiveRecord::Base.connection.select_all <<~SQL
    SELECT
      tmp.patient_id,
      (SELECT identifier FROM patient_identifier WHERE patient_id = tmp.patient_id AND voided = 0 AND identifier_type = 3 LIMIT 1) as Nat_Id,
      DATE_FORMAT(tmp.date_enrolled, "%d-%b-%y") as artreg_date,
      tmp.age_at_initiation as age,
      tmp.gender
    FROM
      temp_earliest_start_date tmp
  SQL
end

# method to open a given file
def open_spreadsheet(file)
  case File.extname(file)
  when '.csv' then Csv.new(file, nil, :ignore)
  when '.xls' then Roo::Excel.new(file, nil, :ignore)
  when '.xlsx' then Roo::Excelx.new(file)
  else raise "Unknown file type: #{file}"
  end
end

# method to read the contents of mpc file
def load_imported_items(file)
  @items = []
  spreadsheet = open_spreadsheet file
  (2..spreadsheet.last_row).each do |i|
    # items << Hash[[header, spreadsheet.sheet(1).row(i)].transpose]
    @items << { 'patient_id' => spreadsheet.sheet(1).row(i)[1], 'Nat_Id' => spreadsheet.sheet(1).row(i)[0],
                'artreg_date' => spreadsheet.sheet(1).row(i)[2].strftime('%d-%b-%y'),
                'age' => spreadsheet.sheet(1).row(i)[3], 'gender' => spreadsheet.sheet(1).row(i)[5] }
  end
end

# method to get patient missed by poc
def missed_by_poc
  puts (@poc.to_a - @items).length
end

fetch_poc_clients
load_imported_items '/home/roy/Documents/mpc_list.xlsx'

missed_by_poc

# puts fetch_poc_clients
