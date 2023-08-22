# frozen_string_literal: true

module ARTService
  module Reports
    module Pepfar
      # This class is used to generate the SC_CURR report
      # The current number of ARV drug units (bottles) at the end of the reporting period by ARV drug category
      class ScCurr
        DrugCategory = {
          'TLD 30-count bottles' => { drugs: [983], quantity: 30 },
          'TLD 90-count bottles' => { drugs: [983], quantity: 90 },
          'TLD 180-count bottles' => { drugs: [983], quantity: 180 },
          'TLE/400 30-count bottles' => { drugs: [735], quantity: 30 },
          'TLE/400 90-count bottles' => { drugs: [735], quantity: 90 },
          'TLE 600/TEE bottles' => { drugs: [11], quantity: 'N/A' },
          'DTG 10 90-count bottles' => { drugs: [980], quantity: 90 },
          'DTG 50 30-count bottles' => { drugs: [982], quantity: 30 },
          'LPV/r 100/25 tabs 60 tabs/bottle' => { drugs: [23, 73, 74, 739, 977, 1045], quantity: 60 },
          'LPV/r 40/10 (pediatrics) bottles' => { drugs: [94, 979], quantity: 'N/A' },
          'NVP (adult) bottles' => { drugs: [22, 613], quantity: 'N/A' },
          'NVP (pediatric) bottles' => { drugs: [21, 817, 968, 971], quantity: 'N/A' },
          'Other (adult) bottles' => { drugs: [
            3, 5, 6, 10, 38, 39, 40, 42, 89, 614, 730, 731, 734, 738,
            814, 815, 932, 933, 934, 952, 954, 955, 957, 969, 976, 978, 984, 1217, 1213, 14
          ], quantity: 'N/A' },
          'Other (pediatric) bottles' => { drugs: [
            2, 9, 28, 29, 30, 31, 32, 36, 37, 41, 70, 71, 72, 90, 91,
            95, 104, 177, 732, 733, 736, 737, 813, 816, 981, 1043, 1044, 1214, 1215
          ], quantity: 'N/A' }
        }.freeze

        def initialize(start_date:, end_date:, **_kwargs)
          @start_date = start_date
          @end_date = end_date
        end

        def find_report
          initialize_report
          process_report
          @report
        end

        private

        def initialize_report
          @report = []
          DrugCategory.each do |category, drug|
            @report << {
              category: category,
              drug_id: drug[:drugs],
              units: 0,
              quantity: drug[:quantity]
            }
          end
        end

        def process_report
          current_stock.each do |item|
            # Find the drug category
            drug_category = @report.find { |category| category[:drug_id].include?(item.drug_id) && category[:quantity] == item.pack_size }
            drug_category ||= @report.find { |category| category[:drug_id].include?(item.drug_id) && category[:quantity] == 'N/A' }
            next unless drug_category

            drug_category[:units] += (item.current_quantity / item.pack_size).to_i
          end
        end

        def current_stock
          drugs = DrugCategory.map { |_, drug| drug[:drugs] }.flatten.uniq
          PharmacyBatchItem.where('expiry_date >= ? AND expiry_date >= ? AND drug_id IN (?)', @start_date, @end_date, drugs)
        end
      end
    end
  end
end
