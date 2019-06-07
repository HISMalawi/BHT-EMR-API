# frozen_string_literal: true

require 'set'

module ARTService
  module Reports
    # Cohort report builder class.
    #
    # This class only provides one public method (start_build_report) besides
    # the constructor. This method must be called to build report and save
    # it to database.
    class Cohort
      include ModelUtils

      def initialize(name:, type:, start_date:, end_date:)
        @name = name
        @start_date = start_date
        @end_date = end_date
        @type = type
        @cohort_builder = CohortBuilder.new
        @cohort_struct = CohortStruct.new
      end

      def build_report
        @cohort_builder.build(@cohort_struct, @start_date, @end_date)
        save_report
      end

      def find_report
        Report.where(type: @type, name: @name,
                     start_date: @start_date, end_date: @end_date)\
              .order(date_created: :desc)\
              .first
      end

      def defaulter_list(pepfar)
        data = ActiveRecord::Base.connection.select_all <<EOF
        SELECT o.patient_id, min(start_date) start_date FROM orders o                      
        INNER JOIN drug_order od ON od.order_id = o.order_id AND o.voided = 0
        INNER JOIN drug d ON d.drug_id = od.drug_inventory_id
        INNER JOIN concept_set s ON s.concept_id = d.concept_id
        INNER JOIN patient_program pp ON pp.patient_id = o.patient_id
        WHERE s.concept_set = 1085 AND od.quantity > 0
        AND pp.program_id = 1
        GROUP BY o.patient_id;
EOF

        patients = []

        (data || []).each do |r|
          patient_id = r['patient_id'].to_i

          if pepfar == false
            record = ActiveRecord::Base.connection.select_one <<EOF
            SELECT patient_outcome(#{patient_id}, DATE('#{@end_date}')) AS outcome,
            current_defaulter_date(#{patient_id}, TIMESTAMP('#{@end_date.to_date.strftime('%Y-%m-%d 23:59:59')}')) AS defaulter_date;
EOF

          else
            record = ActiveRecord::Base.connection.select_one <<EOF
            SELECT current_pepfar_defaulter(#{patient_id}, TIMESTAMP('#{@end_date}')) AS outcome,
            current_pepfar_defaulter_date(#{patient_id}, TIMESTAMP('#{@end_date.to_date.strftime('%Y-%m-%d 23:59:59')}')) AS defaulter_date;
EOF

            record['outcome'] = (record['outcome'].to_i == 1 ? 'Defaulted' : nil)
          end

          if record['outcome'] == 'Defaulted'
            defaulter_date = record['defaulter_date'].to_date rescue nil
            next if defaulter_date.blank?

            date_within = (defaulter_date >= @start_date.to_date && defaulter_date <= @end_date.to_date)
            next unless date_within

            person = ActiveRecord::Base.connection.select_one <<EOF
            SELECT i.identifier arv_number, p.birthdate,
              p.gender, n.given_name, n.family_name, p.person_id patient_id,
              patient_reason_for_starting_art_text(p.person_id) art_reason,
              a.value cell_number,
              s.state_province district, s.county_district ta,
              s.city_village village
            FROM person p
            LEFT JOIN patient_identifier i ON i.patient_id = p.person_id
            AND i.voided = 0 AND i.identifier_type = 4 
            INNER JOIN person_name n ON n.person_id = p.person_id AND n.voided = 0
            LEFT JOIN person_attribute a ON a.person_id = p.person_id
            AND a.voided = 0 AND a.person_attribute_type_id = 12
            LEFT JOIN person_address s ON s.person_id = p.person_id  
            WHERE p.person_id = #{patient_id} GROUP BY p.person_id
            ORDER BY p.person_id, p.date_created;
EOF

            next if person.blank?

            patients << {
              person_id: patient_id,
              given_name: person['given_name'],
              family_name: person['family_name'],
              birthdate: person['birthdate'],
              gender: person['gender'],
              arv_number: person['arv_number'],
              outcome: 'Defaulted',
              defaulter_date: record['defaulter_date'],
              art_reason: record['art_reason'],
              cell_number: person['cell_number'],
              district: person['district'],
              ta: person['ta'],
              village: person['village'],
              arv_number: person['arv_number']
            }
          end
        end

        return patients
      end

      def cohort_report_drill_down(id)
        people = []

        patients = ActiveRecord::Base.connection.select_all <<EOF
        SELECT i.identifier arv_number, p.birthdate,
          p.gender, n.given_name, n.family_name, p.person_id patient_id
        FROM person p
        INNER JOIN cohort_drill_down c ON c.patient_id = p.person_id
        LEFT JOIN patient_identifier i ON i.patient_id = p.person_id
        AND i.voided = 0 AND i.identifier_type = 4 
        LEFT JOIN person_name n ON n.person_id = p.person_id AND n.voided = 0
        WHERE c.reporting_report_design_resource_id = #{id} 
        GROUP BY p.person_id ORDER BY p.person_id, p.date_created;
EOF

        return {} if patients.blank?
        
        patients.select do |person|
          people << {
            person_id: person['patient_id'],
            given_name: person['given_name'],
            family_name: person['family_name'],
            birthdate: person['birthdate'],
            gender: person['gender'],
            arv_number: person['arv_number']
          }
        end

        return people
      end

      private

      LOGGER = Rails.logger

      # Writes the report to database
      def save_report
        report = Report.create(name: @name, start_date: @start_date,
                               end_date: @end_date, type: @type,
                               renderer_type: 'PDF')

        values = save_report_values(report)

        { report: report, values: values }
      end

      # Writes the report values to database
      def save_report_values(report)
        @cohort_struct.values.collect do |value|
          puts "Saving #{value.name} = #{value_contents_to_json(value.contents)}"
          report_value = ReportValue.create(report: report,
                                            name: value.name,
                                            indicator_name: value.indicator_name,
                                            indicator_short_name: value.indicator_short_name,
                                            description: value.description,
                                            contents: value_contents_to_json(value.contents))

          report_value_saved = report_value.errors.empty?
          unless report_value_saved
            raise "Failed to save report value: #{report_value.errors.as_json}"
          else
            save_patients(report_value, value_contents_to_json(value).contents)
          end

          report_value
        end
      end

      def value_contents_to_json(value_contents)
        if value_contents.respond_to?(:each) && !value_contents.is_a?(String)
          if value_contents.respond_to?(:length)
            value_contents.length
          elsif value_contents.respond_to?(:size)
            value_contents.size
          else
            value_contents
          end
        else
          value_contents
        end
      end

      def save_patients(r, values)
        return if values.blank?
        patient_ids = []

        begin
          
          (values.rows || []).each do |v|  
            patient_ids << v[0]
          end  
        
        rescue
          
          begin 
            if values.first.include?(:patient_id)
              values.select do |obj|
                patient_ids << obj[:patient_id]
              end
            end
          rescue
            begin
              values.select do |patient_id|
                patient_ids << patient_id
              end
            rescue
              puts "#{r.name} +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #{values.inspect}"
              return
            end
          end

        end
    
        patient_ids.select do |patient_id|
        ActiveRecord::Base.connection.execute <<EOF
        INSERT INTO cohort_drill_down VALUES(NULL, #{r.id}, #{patient_id});
EOF

        end
      end

    end
  end

      
end
