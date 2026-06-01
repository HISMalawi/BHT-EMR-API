begin
  require './lib/ml/extract_training_data.rb'
rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace.first(5)
end
