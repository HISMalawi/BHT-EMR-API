module ArtService
  module Reports
    # rubocop:disable Metrics/ClassLength
    class MaternalStatus
        include CommonSqlQueryUtils
        include ModelUtils
        attr_reader :start_date, :end_date, :location

      def initialize(start_date:, end_date:, **kwargs)
        @start_date = start_date&.to_date
        raise InvalidParameterError, 'start_date is required' unless @start_date

        @end_date = end_date&.to_date || @start_date + 12.months
        raise InvalidParameterError, "start_date can't be greater than end_date" if @start_date > @end_date

        @occupation = kwargs.delete(:occupation)
        @type = kwargs.delete(:application)
        @patient_ids = kwargs.delete(:patient_ids)&.split(',') || []
      end

      def find_report
        vl_maternal_status
      end
      
      def process_data
        clear_maternal_status
        load_pregnant_women
        load_breast_feeding
      end

      private 

      def vl_maternal_status(patient_list)
        return { FP: [], FBf: [] } if patient_list.blank?

        pregnant = pregnant_women(patient_list).map { |woman| woman['person_id'].to_i }
        return { FP: pregnant, FBf: [] } if (patient_list - pregnant).blank?

        feeding = breast_feeding(patient_list - pregnant).map { |woman| woman['person_id'].to_i }

        {
          FP: pregnant,
          FBf: feeding
        }
      end

      def pregnant_women(patient_list)
        ActiveRecord::Base.connection.execute <<~SQL
          SELECT person_id
          FROM temp_maternal_status 
          WHERE maternal_status = 'FP' AND patient_od IN (#{patient_list.join(',')})
        SQL
      end

      def breast_feeding(patient_list)
        ActiveRecord::Base.connection.execute <<~SQL
          SELECT person_id
          FROM temp_maternal_status 
          WHERE maternal_status = 'FBf' AND patient_id IN (#{patient_list.join(',')})
        SQL
      end

      def load_pregnant_women
        ActiveRecord::Base.connection.execute <<~SQL
          INSERT INTO temp_maternal_status (patient_id, site_id, maternal_status)
          SELECT o.person_id, 'FP' as maternal_status
          FROM obs  o
          INNER JOIN cdr_temp_cohort_members  c ON c.patient_id = o.person_id AND c.gender = 'F'
          LEFT JOIN obs  a ON a.person_id = o.person_id AND a.obs_datetime > o.obs_datetime AND a.concept_id IN (#{pregnant_concepts.to_sql}) AND a.voided = 0
          AND a.obs_datetime >= DATE(#{ActiveRecord::Base.connection.quote(start_date)}) AND a.obs_datetime < DATE(#{ActiveRecord::Base.connection.quote(end_date)}) + INTERVAL 1 DAY
          WHERE a.obs_id is null
            AND o.obs_datetime >= DATE(#{ActiveRecord::Base.connection.quote(start_date)})
            AND o.obs_datetime < DATE(#{ActiveRecord::Base.connection.quote(end_date)}) + INTERVAL 1 DAY
            AND o.voided = 0
            AND o.concept_id in (#{pregnant_concepts.to_sql})
            AND o.value_coded IN (#{yes_concepts.join(',')})
          GROUP BY o.person_id
        SQL
      end

      def load_breast_feeding
        ActiveRecord::Base.connection.execute <<~SQL
          INSERT INTO temp_maternal_status  (patient_id, site_id, maternal_status)
          SELECT o.person_id,  'FBf' as maternal_status
          FROM obs  o
          INNER JOIN cdr_temp_cohort_members  c ON c.patient_id = o.person_id AND c.gender = 'F'
          LEFT JOIN obs  a ON a.person_id = o.person_id AND a.obs_datetime > o.obs_datetime AND a.concept_id IN (#{breast_feeding_concepts.to_sql}) AND a.voided = 0
          AND a.obs_datetime >= DATE(#{ActiveRecord::Base.connection.quote(start_date)}) AND a.obs_datetime < DATE(#{ActiveRecord::Base.connection.quote(end_date)}) + INTERVAL 1 DAY
          WHERE a.obs_id is null
            AND o.obs_datetime >= DATE(#{ActiveRecord::Base.connection.quote(start_date)})
            AND o.obs_datetime < DATE(#{ActiveRecord::Base.connection.quote(end_date)}) + INTERVAL 1 DAY
            AND o.voided = 0
            AND o.concept_id IN (#{breast_feeding_concepts.to_sql})
            AND o.value_coded IN (#{yes_concepts.join(',')})
            AND o.person_id NOT IN (SELECT c.patient_id FROM temp_maternal_status  c)
          GROUP BY o.person_id
        SQL
      end

      def clear_maternal_status
        ActiveRecord::Base.connection.execute <<~SQL
          DELETE FROM temp_maternal_status where site_id = #{location}
        SQL
      end
      
      def yes_concepts
        @yes_concepts ||= ConceptName.where(name: 'Yes').select(:concept_id).map do |record|
          record['concept_id'].to_i
        end
      end

      def pregnant_concepts
        @pregnant_concepts ||= ConceptName.where(name: ['Is patient pregnant?', 'patient pregnant'])
                                            .select(:concept_id)
      end

      def breast_feeding_concepts
        @breast_feeding_concepts ||= ConceptName.where(name: ['Breast feeding?', 'Breast feeding', 'Breastfeeding'])
                                                  .select(:concept_id)
      end

      def encounter_types
        @encounter_types ||= EncounterType.where(name: ['HIV CLINIC CONSULTATION', 'HIV STAGING'])
                                            .select(:encounter_type_id)
      end
    end
  end
end