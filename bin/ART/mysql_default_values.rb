# frozen_string_literal: true

# this will be use to fix the columns default values in mysql 8 from the default values that were being used in 5.6

# get all the tables in the database
tables = ActiveRecord::Base.connection.tables
# loop through the tables
tables.each do |table|
    # get the table columns and loop through them
    ActiveRecord::Base.connection.columns(table).each do |column|
        # check if the column has a default value
        if column.default
            # check if the column data type is a date then use current_timestamp()
            if column.type == :date
                puts "ALTER TABLE #{table} MODIFY #{column.name} DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP;"
                ActiveRecord::Base.connection.execute("ALTER TABLE #{table} MODIFY #{column.name} DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP;")
            # check if the column data type is a datetime then use current_timestamp()
            elsif column.type == :datetime
                puts "ALTER TABLE #{table} MODIFY #{column.name} DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP;"
                ActiveRecord::Base.connection.execute("ALTER TABLE #{table} MODIFY #{column.name} DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP;")
            # check if the column data type is a time then use current_timestamp()
            else
                # just print the table name and the column name
                puts "#{table} #{column.name} #{column.type} #{column.default}"
            end
        end
    end
end
