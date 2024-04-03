# frozen_string_literal: true

module ArtService
  module Reports
    module Pepfar
      # This class is used to generate the SC_CURR report
      # The current number of ARV drug units (bottles) at the end of the reporting period by ARV drug category
      class ScCurr
        DRUG_CATEGORY = {
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
          # remove the drug_id from the report
          @report.each { |category| category.delete(:drug_id) }
          @report
        end

        private

        def initialize_report
          @report = []
          DRUG_CATEGORY.each do |category, drug|
            @report << {
              category:,
              drug_id: drug[:drugs],
              units: 0,
              quantity: drug[:quantity],
              granular_spec: []
            }
          end
        end

        # rubocop:disable Metrics/AbcSize
        # rubocop:disable Metrics/CyclomaticComplexity
        def process_report
          current_stock.each do |item|
            # Find the drug category
            drug_category = @report.find do |category|
              category[:drug_id].include?(item.drug_id) && category[:quantity] == item.pack_size
            end
            drug_category ||= @report.find do |category|
              category[:drug_id].include?(item.drug_id) && category[:quantity] == 'N/A'
            end
            next unless drug_category

            bottles = (item.current_quantity / item.pack_size).to_i
            drug_category[:units] += bottles
            # check if the drug is already in the granular_spec
            granular_spec = drug_category[:granular_spec].find { |spec| spec[:drug_name] == item.drug.name }
            if granular_spec
              granular_spec[:units] += bottles
            else
              drug_category[:granular_spec] << {
                drug_name: item.drug.name,
                units: bottles
              }
            end
          end
        end
        # rubocop:enable Metrics/AbcSize
        # rubocop:enable Metrics/CyclomaticComplexity

        def current_stock
          drugs = DRUG_CATEGORY.map { |_, drug| drug[:drugs] }.flatten.uniq
          PharmacyBatchItem.where(
            'expiry_date >= ? AND delivery_date <= ? AND drug_id IN (?) AND current_quantity > 0', @end_date, @end_date, drugs
          )
        end
      end
    end
  end
end
