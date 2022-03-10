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
					@use_filing_number = GlobalProperty.find_by(property: 'use.filing.numbers')
																							&.property_value
																							&.casecmp?('true')
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
						{name: "Other (pediatric) bottles", units: 0, quantity: 'N/A', dispensations: []},
						{name: "Other bottles", units: 0, quantity: 'N/A', dispensations: []}
					]

					dispensations = get_dispensations
					other_drugs = []

					(dispensations || {}).map do |order_id, dispensation_info|
						quantities = dispensation_info[:quantities]

						(quantities || []).each do |quantity|
							fetched_category, unit = get_category(dispensation_info[:drug_id], quantity)
							drug_category.map do |category|
								if category[:name] == fetched_category
									category[:units] += unit
									category[:dispensations] << [
										dispensation_info[:name],
										quantity,
										dispensation_info[:start_date],
										dispensation_info[:identifier],
										dispensation_info[:patient_id]
									]
									break
								end
							end
						end

					end

					return drug_category
				end

				def get_category(drug_id, quantity)
					DrugCategory.map do |name, data|
						if data[:drugs].include?(drug_id)
							qty = data[:quantity]
							return [name, 1] if qty == 'N/A'
							return [name, 1] if qty.to_i == quantity.to_i
						end
					end

					DrugCategory.map do |name, data|
						if data[:drugs].include?(drug_id)
							qty = data[:quantity]
							if(quantity.to_i % qty == 0)
								return [name, (quantity / qty).to_i]
							end
						end
					end
					return ["Other bottles", 1]
				end

				def get_dispensations
					amount_dispensed = ConceptName.find_by(name: 'Amount of drug dispensed').concept_id
					identifier_type = PatientIdentifierType.find_by(name: 'ARV number').id
					identifier_type_name = @use_filing_number ? 'Filing Number' : 'ARV Number'
					identifier_type = PatientIdentifierType.find_by_name!(identifier_type_name).id

					dispensations = {}
					orders = ActiveRecord::Base.connection.select_all <<~SQL
					SELECT
						orders.order_id, orders.start_date, drug_order.quantity,drug.name,
						orders.patient_id, obs.value_numeric, orders.start_date,
						patient_identifier.identifier,drug.drug_id
					FROM orders
					INNER JOIN drug_order ON drug_order.order_id = orders.order_id AND drug_order.quantity > 0
					INNER JOIN arv_drug ON arv_drug.drug_id = drug_order.drug_inventory_id
					INNER JOIN drug ON drug.drug_id = arv_drug.drug_id
					INNER JOIN encounter ON encounter.encounter_id = orders.encounter_id
					AND encounter.program_id = #{Program.find_by(name: 'HIV Program').id}
					INNER JOIN(
					SELECT MAX(start_date) start_date, patient_id, orders.order_id FROM orders
					INNER JOIN drug_order ON drug_order.order_id = orders.order_id
					INNER JOIN arv_drug ON arv_drug.drug_id = drug_order.drug_inventory_id
					WHERE start_date BETWEEN '#{@completion_start_date}' AND '#{@completion_end_date}'
					AND orders.order_type_id = 1 AND orders.voided = 0
					GROUP BY orders.order_id, orders.patient_id ORDER BY orders.start_date)
					AS order_start_date ON orders.order_id = order_start_date.order_id
					INNER JOIN obs ON obs.order_id = orders.order_id AND obs.voided = 0
					AND obs.concept_id = #{amount_dispensed} AND obs.value_numeric > 0
					LEFT JOIN patient_identifier ON patient_identifier.patient_id = orders.patient_id
					AND patient_identifier.identifier_type = #{identifier_type}
					AND patient_identifier.voided = 0
					ORDER BY orders.start_date ASC, orders.patient_id;
					SQL

					(orders || []).each do |order|
						order_id = order["order_id"].to_i
						dispensations[order_id] = {
							quantity: order["quantity"].to_f,
							name: order["name"],
							drug_id: order["drug_id"].to_i,
							identifier: (order["identifier"] ||= "N/A"),
							start_date: order["start_date"].to_date,
							patient_id: order["patient_id"].to_i,
							quantities: []
						} if dispensations[order_id].blank?

					  dispensations[order_id][:quantities] << order["value_numeric"].to_f
					end

					return dispensations
				end

			end
		end
	end
end