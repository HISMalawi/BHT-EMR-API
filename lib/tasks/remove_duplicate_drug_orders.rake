# lib/tasks/remove_duplicate_drug_orders.rake
# rails drug_orders:remove_duplicates

# SELECT 
#   o.patient_id,
#   DATE(o.start_date) as order_date,
#   do.drug_inventory_id,
#   COUNT(*) as duplicate_count,
#   GROUP_CONCAT(o.order_id ORDER BY o.order_id ASC SEPARATOR ',') as order_ids,
#   GROUP_CONCAT(TIME(o.start_date) ORDER BY o.order_id ASC SEPARATOR ', ') as order_times
# FROM dbName.orders o
# INNER JOIN dbName.drug_order do ON o.order_id = do.order_id
# WHERE o.voided = 0
#   AND o.order_type_id = (SELECT order_type_id FROM dbName.order_type WHERE name = 'Drug order' LIMIT 1)
#   AND o.patient_id = (SELECT patient_id FROM dbName.encounter WHERE encounter_id = 560954)
#   AND DATE(o.start_date) = '2025-06-02'
# GROUP BY o.patient_id, DATE(o.start_date), do.drug_inventory_id
# HAVING COUNT(*) > 1;

namespace :drug_orders do
  desc 'Remove duplicate drug orders with same drug_id on same start_date for same patient'
  task remove_duplicates: :environment do
    
    # Start timing the entire process
    start_time = Time.now
    
    puts "\n===== Duplicate Drug Orders Removal Process ====="
    puts "Started at: #{start_time.strftime('%Y-%m-%d %H:%M:%S')}"
    
    # Counters
    counters = {
      total_patients_processed: 0,
      total_duplicate_groups: 0,
      total_orders_voided: 0,
      total_orders_kept: 0,
      errors: 0
    }
    
    begin
      ActiveRecord::Base.transaction do
        # Find all duplicate drug orders grouped by patient_id, start_date (DATE only), and drug_id
        # Keep the earliest created order (oldest order_id)
        duplicate_query = <<-SQL
          SELECT 
            o.patient_id,
            DATE(o.start_date) as order_date, -- CHANGED
            do.drug_inventory_id,
            COUNT(*) as duplicate_count,
            GROUP_CONCAT(o.order_id ORDER BY o.order_id ASC SEPARATOR ',') as order_ids
          FROM orders o
          INNER JOIN drug_order do ON o.order_id = do.order_id
          WHERE o.voided = 0
            AND o.order_type_id = (SELECT order_type_id FROM order_type WHERE name = 'Drug order' LIMIT 1)
          GROUP BY o.patient_id, DATE(o.start_date), do.drug_inventory_id -- CHANGED
          HAVING COUNT(*) > 1
          ORDER BY o.patient_id, DATE(o.start_date) -- CHANGED
        SQL
        
        duplicates = ActiveRecord::Base.connection.execute(duplicate_query)
        
        puts "Found #{duplicates.count} duplicate groups to process...\n"
        
        duplicates.each do |duplicate_group|
          patient_id = duplicate_group[0]
          order_date = duplicate_group[1]
          drug_id = duplicate_group[2]
          duplicate_count = duplicate_group[3]
          order_ids_str = duplicate_group[4]
          
          # Split order IDs and convert to integers
          order_ids = order_ids_str.split(',').map(&:to_i)
          
          # Keep the first (oldest) order, void the rest
          order_to_keep = order_ids.first
          orders_to_void = order_ids[1..-1]
          
          puts "\n--- Patient ID: #{patient_id} | Date: #{order_date} | Drug ID: #{drug_id} ---"
          puts "Total duplicates: #{duplicate_count}"
          puts "Keeping order_id: #{order_to_keep}"
          puts "Voiding order_ids: #{orders_to_void.join(', ')}"
          
          begin
            # Void duplicate orders
            orders_to_void.each do |order_id|
              void_query = <<-SQL
                UPDATE orders 
                SET voided = 1, 
                    voided_by = 1,
                    date_voided = NOW(),
                    void_reason = 'Duplicate drug order on same date - Auto-voided by rake task'
                WHERE order_id = ?
              SQL
              
              ActiveRecord::Base.connection.execute(
                ActiveRecord::Base.sanitize_sql_array([void_query, order_id])
              )
              
              counters[:total_orders_voided] += 1
              print "."
            end
            
            counters[:total_orders_kept] += 1
            counters[:total_duplicate_groups] += 1
            
          rescue StandardError => e
            puts "\nError processing patient #{patient_id}, date #{order_date}: #{e.message}"
            counters[:errors] += 1
            raise ActiveRecord::Rollback, "Failed to void duplicate orders"
          end
        end
        
        # Count unique patients processed
        patient_ids = duplicates.map { |d| d[0] }.uniq
        counters[:total_patients_processed] = patient_ids.count
        
        puts "\n\n✓ Transaction completed successfully"
      end
      
    rescue StandardError => e
      puts "\n✗ Transaction rolled back due to error: #{e.message}"
      puts e.backtrace.first(5).join("\n")
    end
    
    end_time = Time.now
    
    # Calculate durations and print summary
    puts "\n\n===== Removal Complete ====="
    puts "Finished at: #{end_time.strftime('%Y-%m-%d %H:%M:%S')}"
    
    # Performance summary
    total_duration = end_time - start_time
    puts "\n--- Performance Summary ---"
    puts "Total Runtime: #{total_duration.round(2)} seconds"
    
    # Print statistics
    puts "\n--- Removal Statistics ---"
    puts "Patients Processed: #{counters[:total_patients_processed]}"
    puts "Duplicate Groups Found: #{counters[:total_duplicate_groups]}"
    puts "Orders Kept: #{counters[:total_orders_kept]}"
    puts "Orders Voided: #{counters[:total_orders_voided]}"
    puts "Errors: #{counters[:errors]}"
    
    # Memory usage
    if defined?(Process)
      memory_usage = `ps -o rss= -p #{Process.pid}`.to_i / 1024.0
      puts "\n--- System Resources ---"
      puts "Memory Usage: #{memory_usage.round(2)} MB"
    end
    
    puts "\n===== Process Complete ====="
  end
end