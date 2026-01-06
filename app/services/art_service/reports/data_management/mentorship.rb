# frozen_string_literal: true

module ArtService
  module Reports
    module DataManagement
      class Mentorship
        include CommonSqlQueryUtils
        include ModelUtils
        attr_reader :start_date, :end_date, :location, :patient_ids

        def initialize(start_date:, end_date:, **kwargs)
          @start_date = start_date&.to_date
          raise InvalidParameterError, 'start_date is required' unless @start_date

          @end_date = end_date&.to_date || @start_date + 12.months
          raise InvalidParameterError, "start_date can't be greater than end_date" if @start_date > @end_date

          patient_ids = kwargs.delete(:patient_ids)
          @patient_ids = patient_ids.split(',').map(&:to_i) if patient_ids.class == String
          @patient_ids = patient_ids if patient_ids.class == Array
        end

        def find_report
          mentorship_report
        end

        def dispensations_drill_down(creator)
          #arv_number, patient_id, visit_date, regimen, quantity
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT o.patient_id, 
                   DATE(encounter_datetime) visit_date, 
                   patient_current_regimen(o.patient_id, DATE(encounter_datetime)) regimen, 
                   quantity,
                   pi.identifier arv_number,
                   e.creator 
            FROM orders o
              INNER JOIN drug_order d ON d.order_id = o.order_id
              INNER JOIN drug dr ON dr.drug_id = d.drug_inventory_id
              INNER JOIN encounter e ON e.encounter_id = o.encounter_id
              LEFT JOIN patient_identifier pi ON pi.patient_id = o.patient_id
                AND pi.identifier_type = (
                   SELECT patient_identifier_type_id FROM patient_identifier_type WHERE name = 'ARV Number'
                )
            WHERE o.patient_id IN(#{patient_ids.join(',')}) 
              AND o.voided = 0 
              AND o.start_date BETWEEN '#{@start_date}' AND '#{@end_date}'
              AND o.order_type_id = #{OrderType.find_by_name('Drug order').id}
              AND d.quantity > 0
              AND dr.concept_id IN (#{Drug.arv_drugs.pluck(:concept_id).join(',')})
              AND e.creator = #{creator};
          SQL
        end

        def vl_postponed_drill_down
          # art_number, visit_date, vl due date, next milestone
          due_dates = load_vl_due_dates(patient_ids)
          arv_numbers = arv_numbers(patient_ids)
          
          patient_ids.each_with_object([]) do |patient_id, array|
            next unless due_dates[patient_id]
            array << {
              patient_id:,
              arv_number: arv_numbers[patient_id],
              visit_date: find_visit_date(patient_id, due_dates[patient_id]),
              vl_due_date: due_dates[patient_id],
              next_milestone: due_dates[patient_id] + 12.months
            }
          end
        end

        def find_visit_date(patient_id, vl_date)
          encounter = Encounter.where(patient_id:)
                            .where('encounter_datetime > ?', vl_date)
                            .order(encounter_datetime: :asc)
                            .first
          encounter&.encounter_datetime&.to_date
        end

        def arv_numbers(patient_ids)
          arv_number_type_id = PatientIdentifierType.find_by_name('ARV Number').id
          PatientIdentifier.where(patient_id: patient_ids, identifier_type: arv_number_type_id)
                          .index_by(&:patient_id)
                          .transform_values(&:identifier)
        end

        def mentorship_report
          clients_data = find_clients_seen
          return {} if clients_data.empty?

          # Batch load all data upfront
          user_map = load_users(clients_data)
          art_dispensations_map = load_art_dispensations(clients_data)
          vl_postponed_map = load_vl_postponed_patients(clients_data)

          # Build report from cached data
          clients_data.each_with_object({}) do |client, report|
            build_report_data(client, report, user_map, art_dispensations_map, vl_postponed_map)
          end
        end

        private

          def find_clients_seen
            ActiveRecord::Base.connection.select_all <<~SQL
              SELECT DISTINCT(patient_id), creator, DATE(encounter_datetime) visit_date FROM encounter
                WHERE encounter_datetime BETWEEN '#{@start_date}' AND '#{@end_date}'
                AND voided = 0;
            SQL
          end

          def load_users(clients_data)
            creator_ids = clients_data.map { |c| c['creator'] }.uniq
            User.where(user_id: creator_ids).index_by(&:user_id).transform_values(&:username)
          end

          def load_art_dispensations(clients_data)
            arv_drug_ids = Drug.arv_drugs.pluck(:drug_id)

            # Query all dispensations at once
            dispensations = Order.joins(:encounter, :drug_order)
              .where(
                encounter: {
                  patient_id: clients_data.map { |c| c['patient_id'] }.uniq
                }
              )
              .where('DATE(encounter.encounter_datetime) BETWEEN ? AND ?', @start_date, @end_date)
              .where(drug_order: { drug_inventory_id: arv_drug_ids, quantity: 1..Float::INFINITY })
              .select(
                'encounter.patient_id',
                'DATE(encounter.encounter_datetime) AS visit_date',
                'encounter.creator'
              )
              .distinct

            # Build a set of composite keys for quick lookup
            dispensations.each_with_object(Set.new) do |disp, set|
              set.add("#{disp.patient_id}_#{disp.visit_date}_#{disp.creator}")
            end
          end

          def load_vl_postponed_patients(clients_data)
            patient_ids = clients_data.map { |c| c['patient_id'] }.uniq
            return Set.new if patient_ids.empty?
            
            # Batch load VL due dates for all patients
            due_dates_map = load_vl_due_dates(patient_ids)
            
            # Batch load all skipped VL observations at once
            postponed_set = check_skipped_viral_loads(due_dates_map)
            
            postponed_set
          end

          def load_vl_due_dates(patient_ids)
            # Batch load all VL-related data for all patients
            vl_data = load_all_vl_data(patient_ids)
            
            # Calculate due dates using cached data
            patient_ids.each_with_object({}) do |patient_id, map|
              begin
                due_date = calculate_vl_due_date(patient_id, vl_data)
                map[patient_id] = due_date if due_date
              rescue StandardError => e
                Rails.logger.warn("Failed to get VL due date for patient #{patient_id}: #{e.message}")
              end
            end
          end

          def load_all_vl_data(patient_ids)
            {
              recent_viral_loads: load_recent_viral_loads(patient_ids),
              last_viral_loads: load_last_viral_loads(patient_ids),
              recent_vl_skips: load_recent_vl_skips(patient_ids)
            }
          end

          def load_recent_viral_loads(patient_ids)
            return {} if patient_ids.empty?
            
            specimens = ConceptName.where(name: ['Blood', 'DBS (Free drop to DBS card)', 'DBS (Using capillary tube)', 'Plasma'])
                                  .pluck(:concept_id)
            vl_test_concept = ConceptName.find_by(name: 'Test type')&.concept_id
            vl_value_concept = ConceptName.find_by(name: 'Viral Load')&.concept_id
            
            orders = Lab::LabOrder.joins(:tests)
              .where(concept_id: specimens, patient_id: patient_ids)
              .where('start_date BETWEEN ? AND ?', @end_date - 12.months, @end_date)
              .where(obs: { concept_id: vl_test_concept, value_coded: vl_value_concept })
              .select('orders.patient_id, MAX(orders.start_date) as start_date')
              .group('orders.patient_id')
              
            orders.each_with_object({}) do |order, hash|
              hash[order.patient_id] = OpenStruct.new(start_date: order.start_date)
            end
          end

          def load_last_viral_loads(patient_ids)
            return {} if patient_ids.empty?
            
            specimens = ConceptName.where(name: ['Blood', 'DBS (Free drop to DBS card)', 'DBS (Using capillary tube)'])
                                  .pluck(:concept_id)
            vl_test_concept = ConceptName.find_by(name: 'Test type')&.concept_id
            vl_value_concept = ConceptName.find_by(name: 'Viral Load')&.concept_id
            
            orders = Lab::LabOrder.joins(:tests)
              .where(concept_id: specimens, patient_id: patient_ids)
              .where('start_date <= ?', @end_date)
              .where(obs: { concept_id: vl_test_concept, value_coded: vl_value_concept })
              .select('orders.patient_id, MAX(orders.start_date) as start_date')
              .group('orders.patient_id')
              
            orders.each_with_object({}) do |order, hash|
              hash[order.patient_id] = OpenStruct.new(start_date: order.start_date)
            end
          end

          def load_recent_vl_skips(patient_ids)
            return {} if patient_ids.empty?
            
            concept_ids = ConceptName.where(name: ['Delayed milestones', 'Tests ordered']).pluck(:concept_id)
            
            skips = Observation.where(concept_id: concept_ids, person_id: patient_ids)
              .where('obs_datetime BETWEEN ? AND ?', @end_date - 12.months, @end_date)
              .select('person_id, MAX(obs_datetime) as obs_datetime')
              .group('person_id')
            
            skips.each_with_object({}) do |skip, hash|
              hash[skip.person_id] = OpenStruct.new(obs_datetime: skip.obs_datetime)
            end
          end

          def calculate_vl_due_date(patient_id, vl_data)
            recent_vl = vl_data[:recent_viral_loads][patient_id]
            
            unless recent_vl
              # No VL in last 12 months - check for VL skip
              vl_skip = vl_data[:recent_vl_skips][patient_id]
              return vl_skip.obs_datetime.to_date + 6.months if vl_skip
              
              # Check for any previous VL
              last_vl = vl_data[:last_viral_loads][patient_id]
              return last_vl.start_date.to_date + 12.months if last_vl
              
              # No VL found - return nil to skip this patient
              return nil
            end
            
            # Patient has recent VL - due in 12 months
            recent_vl.start_date.to_date + 12.months
          end

          def check_skipped_viral_loads(due_dates_map)
            return Set.new if due_dates_map.empty?

            # Get concept IDs once
            concept_ids = ConceptName.where(name: ['Delayed milestones', 'Tests ordered'])
                                    .pluck(:concept_id)
            
            # Build conditions for batch query - we need to check each patient's specific date range
            # Query all observations that could be relevant
            observations = Observation.where(
              concept_id: concept_ids,
              person_id: due_dates_map.keys
            ).where('obs_datetime BETWEEN ? AND ?', 
                    due_dates_map.values.min, 
                    @end_date)
            .select(:person_id, :obs_datetime)

            # Group observations by patient
            obs_by_patient = observations.group_by(&:person_id)

            # Check each patient against their specific due date
            postponed_patients = Set.new
            due_dates_map.each do |patient_id, due_date|
              patient_obs = obs_by_patient[patient_id] || []
              # Check if any observation falls within the patient's specific date range
              has_skip = patient_obs.any? do |obs|
                obs.obs_datetime.to_date >= due_date && obs.obs_datetime.to_date <= @end_date
              end
              postponed_patients.add(patient_id) if has_skip
            end

            postponed_patients
          end

          def build_report_data(client, report, user_map, art_dispensations_map, vl_postponed_map)
            creator = client['creator']
            username = user_map[creator] || "Unknown User #{creator}"
            patient_id = client['patient_id']
            visit_date = client['visit_date']

            report[username] ||= {
              'clients_seen' => [],
              'art_dispensations' => [],
              'vl_due_but_postponed' => []
            }

            report[username]['clients_seen'] << patient_id

            # Check dispensation using cached data
            dispensation_key = "#{patient_id}_#{visit_date}_#{creator}"
            if art_dispensations_map.include?(dispensation_key)
              report[username]['art_dispensations'] << patient_id
            end

            # Check VL postponement using cached data
            if vl_postponed_map.include?(patient_id)
              report[username]['vl_due_but_postponed'] << patient_id
            end
          end
      end
    end
  end
end