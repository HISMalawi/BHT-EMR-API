module ARTService
  module Reports
    module Pepfar

      class ScArvdisp
				DrugCategory = {
					"TLD 30-count bottles" => {drugs: [983], quantity: 30},
					"TLD 90-count bottles" => {drugs: [983], quantity: 90},
					"TLD 180-count bottles" => {drugs: [983], quantity: 180},
					"TLE/400 30-count bottles" => {drugs: [735], quantity: 30},
					"TLE/400 90-count bottles" => {drugs: [735], quantity: 90},
					"TLE 600/TEE bottles" => {drugs: [11], quantity: 'N/A'},
				 	"DTG 10 90-count bottles" => {drugs: [980], quantity: 90},
					"LPV/r 100/25 tabs 60 tabs/bottle" => {drugs: [23,73,74,739,977,1045], quantity: 60},
					"LPV/r 40/10 (pediatrics) bottles" => {drugs: [94,979], quantity: 'N/A'},
					"NVP (adult) bottles" => {drugs: [22,613], quantity: 'N/A'},
					"NVP (pediatric) bottles" => {drugs: [21,817,968,971], quantity: 'N/A'},
					"Other (adult) bottles" => {drugs: [
						3,5,6,10,38,39,40,42,89,614,730,731,734,738,
						814,815,932,933,934,952,954,955,957,969,976,978,982,984
					], quantity: 'N/A'},
					"Other (pediatric) bottles" => {drugs: [
						2, 9, 28, 29, 30, 31, 32, 36, 37, 41, 70, 71, 72, 90, 91,
						95, 104, 177, 732, 733, 736, 737, 813, 816, 981, 1043, 1044
					], quantity: 'N/A'}
				}

        def initialize(start_date:, end_date:, rebuild_outcome: false)
          @completion_start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
          @completion_end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')
					@rebuild_outcome = rebuild_outcome
        end

        def report
          return data
        end

        private

        def data

					drug_category = [
						{name: "TLD 30-count bottles",  units: 0, quantity: 30, dispensations: []},
						{name: "TLD 90-count bottles", units: 0, quantity: 90, dispensations: []},
						{name: "TLD 180-count bottles", units: 0, quantity: 180, dispensations: []},
						{name: "TLE/400 30-count bottles", units: 0, quantity: 30, dispensations: []},
						{name: "TLE/400 90-count bottles", units: 0, quantity: 90, dispensations: []},
						{name: "TLE 600/TEE bottles", units: 0, quantity: 'N/A', dispensations: []},
						{name: "DTG 10 90-count bottles", units: 0, quantity: 90, dispensations: []},
						{name: "LPV/r 100/25 tabs 60 tabs/bottle", units: 0, quantity: 60, dispensations: []},
						{name: "LPV/r 40/10 (pediatrics) bottles", units: 0, quantity: 'N/A', dispensations: []},
						{name: "NVP (adult) bottles",  units: 0, quantity: 'N/A', dispensations: []},
						{name: "NVP (pediatric) bottles", units: 0, quantity: 'N/A', dispensations: []},
						{name: "Other (adult) bottles", units: 0, quantity: 'N/A', dispensations: []},
						{name: "Other (pediatric) bottles", units: 0, quantity: 'N/A', dispensations: []}
					]

					dispensations = get_dispensations
					other_drugs = []

					dispensations.map do |order|
						order_quantity = order["quantity"].to_i
						drug_id = order["drug_id"].to_i
						drug_name = order["name"]
						category = get_category(drug_id, order_quantity)

						unless category.blank?
							drug_category.map do |a|
								if a[:name] == category[:name]
									if category[:details][:quantity] == "N/A"
										a[:units] += 1
										a[:dispensations] << [drug_name, order_quantity]
									elsif category[:details][:quantity] == order_quantity
										a[:units] += 1
										a[:dispensations] << [drug_name, order_quantity]
									elsif category[:details][:quantity].to_i > 0 && (order_quantity % category[:details][:quantity] == 0)
										a[:units] += (order_quantity % category[:details][:quantity])
										a[:dispensations] << [drug_name, order_quantity]
									else
										a[:units] += 1
										a[:dispensations] << [drug_name, order_quantity]
									end
								end
							end
						else
							other_drugs << order
						end
					end

					drug_category << {
						name: "Other bottles", units: other_drugs.count,
						quantity: 'N/A', dispensations: other_drugs.map{|o| [o["name"], o["quantity"]]}
					}
					return drug_category
				end

				def get_category(drug_id, order_quantity)
					DrugCategory.map do |name, details|
						if details[:quantity] == order_quantity && details[:drugs].include?(drug_id)
							return {name: name, details: DrugCategory[name]}
						elsif details[:quantity] == 'N/A' && details[:drugs].include?(drug_id)
							return {name: name, details: DrugCategory[name]}
						end
					end

					category = nil
					drug_category = nil

					DrugCategory.map do |name, details|
						if details[:drugs].include?(drug_id)
							if category.blank?
								category = order_quantity % details[:quantity]
								drug_category = {name: name, details: DrugCategory[name]}
							else
								ans = order_quantity % details[:quantity]
								if ans < category
									category = ans
									drug_category = {name: name, details: DrugCategory[name]}
								end
							end
						end
					end

					return drug_category
				end

				def get_dispensations
					ActiveRecord::Base.connection.select_all <<~SQL
						SELECT orders.patient_id, drug.drug_id, drug.name, orders.start_date, quantity FROM orders
						INNER JOIN encounter ON encounter.encounter_id = orders.encounter_id AND encounter.program_id = 1
						INNER JOIN drug_order ON drug_order.order_id = orders.order_id AND drug_order.quantity > 0
						INNER JOIN arv_drug ON arv_drug.drug_id = drug_order.drug_inventory_id
						INNER JOIN drug ON drug.drug_id = drug_order.drug_inventory_id
						INNER JOIN(
						SELECT MAX(start_date) start_date, patient_id, orders.order_id FROM orders
						INNER JOIN drug_order ON drug_order.order_id = orders.order_id
						INNER JOIN arv_drug ON arv_drug.drug_id = drug_order.drug_inventory_id
						WHERE start_date BETWEEN '#{@completion_start_date}' AND '#{@completion_end_date}'
						GROUP BY orders.order_id, orders.patient_id ORDER BY orders.start_date
						) AS order_start_date ON orders.order_id = order_start_date.order_id
						AND orders.patient_id = order_start_date.patient_id

						WHERE orders.order_type_id = 1 AND orders.voided = 0
						GROUP BY orders.order_id ORDER BY orders.start_date ASC, orders.patient_id ASC;
					SQL
				end

			end
		end
	end
end