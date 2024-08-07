# rubocop:disable Style/Documentation, Style/MultilineBlockChain, Layout/LineLength, Metrics/AbcSize, Metrics/ModuleLength, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/BlockLength, Metrics/ParameterLists
# frozen_string_literal: true

module HtsService
  module Reports
    module HtsReportBuilder
      def hts_age_groups
        [
          { less_than_one: '<1 year' },
          { one_to_four: '1-4 years' },
          { five_to_nine: '5-9 years' },
          { ten_to_fourteen: '10-14 years' },
          { fifteen_to_nineteen: '15-19 years' },
          { twenty_to_twenty_four: '20-24 years' },
          { twenty_five_to_twenty_nine: '25-29 years' },
          { thirty_to_thirty_four: '30-34 years' },
          { thirty_five_to_thirty_nine: '35-39 years' },
          { fourty_to_fourty_four: '40-44 years' },
          { fourty_five_to_fourty_nine: '45-49 years' },
          { fifty_to_fifty_four: '50-54 years' },
          { fifty_five_to_fifty_nine: '55-59 years' },
          { sixty_to_sixty_four: '60-64 years' },
          { sixty_five_to_sixty_nine: '65-69 years' },
          { seventy_to_seventy_four: '70-74 years' },
          { seventy_five_to_seventy_nine: '75-79 years' },
          { eighty_to_eighty_four: '80-84 years' },
          { eighty_five_to_eighty_nine: '85-89 years' },
          { ninety_plus: '90 plus years' }
        ].freeze
      end

      def his_patients_rev
        Patient.joins(:person, encounters: :program)
               .where(
                 encounter: {
                   encounter_datetime: @start_date..@end_date,
                   encounter_type: EncounterType.find_by_name('Testing')
                 },
                 program: { program_id: Program.find_by_name('HTC PROGRAM').id }
               ).where.not(person: { birthdate: nil })
      end

      def his_patients_revs(indicators)
        columns = ActiveRecord::Base.connection.columns('obs').map(&:name)
        sql_query = <<~SQL
          SELECT patients.patient_id, person.gender, person.birthdate, encounter.encounter_datetime,
                 CONCAT_WS('/', #{columns.map { |col| "COALESCE(obs.#{col}, 'NULL')" }.join(', ')}) AS observations
          FROM (
              SELECT patient.patient_id
              FROM patient
              INNER JOIN person ON person.person_id = patient.patient_id AND patient.voided = 0#{' '}
              INNER JOIN encounter ON encounter.patient_id = patient.patient_id
              INNER JOIN program ON program.program_id = encounter.program_id
              WHERE encounter.encounter_datetime BETWEEN '#{@start_date}' AND '#{@end_date}'
              AND encounter.encounter_type = (
                  SELECT encounter_type_id FROM encounter_type WHERE name = 'Testing'
              )
              AND program.program_id = (
                  SELECT program_id FROM program WHERE name = 'HTC PROGRAM'
              )
          ) AS patients
          INNER JOIN obs ON patients.patient_id = obs.person_id AND obs.voided = 0
          INNER JOIN person ON person.person_id = patients.patient_id
          INNER JOIN encounter ON encounter.patient_id = patients.patient_id;
        SQL

        results = ActiveRecord::Base.connection.execute(sql_query)

        data = {}

        results.each do |row|
          patient_id = row[0]
          observations = row[4].split('/')
          patient_obs = {}

          columns.each_with_index do |value, index|
            patient_obs[value] = observations[index]
          end

          patient_data = data[patient_id]
          if patient_data.nil?
            patient_data = { 'patientid' => patient_id, 'observations' => [],
                             'demographics' => { 'gender' => row[1], 'person_id' => patient_id, 'birthdate' => row[2], 'encounter_datetime' => row[3] } }
            data[patient_id] = patient_data
          end

          patient_data['observations'] << patient_obs
        end

        process_patient_data(data, indicators)
      end

      def process_patient_data(data, indicators)
        patient_data = []

        data.each_value do |patient_observation|
          observations = patient_observation['observations']
          patient_obs = {}

          indicators.each do |indicator|
            if indicator[:concept_id].is_a?(Integer)
              desired_observation = observations.find { |obs| obs['concept_id'] == indicator[:concept_id].to_s }
              if desired_observation.present?
                val = indicator[:value]
                name = indicator[:name]
                patient_obs[name] =
                  (val == 'value_numeric' ? desired_observation[val].to_i : desired_observation[val])
              else
                patient_obs[name] = nil
              end
            elsif indicator[:concept_id].is_a?(Array)
              indicator[:concept_id].each_with_index do |concept_id, index|
                desired_observation = observations.find { |obs| obs['concept_id'] == concept_id.to_s }
                if desired_observation.present?
                  val = indicator[:value]
                  name = indicator[:name][index]
                  patient_obs[name] =
                    (val == 'value_numeric' ? desired_observation[val].to_i : desired_observation[val])
                else
                  name = indicator[:name][index]
                  patient_obs[name] = nil
                end
              end
            end
          end

          patient_observation['demographics'].each do |key, value|
            patient_obs[key.to_s] = value
          end

          patient_data << patient_obs
        end

        patient_data
      end

      def self_test_clients
        Patient.joins(:person, encounters: %i[observations program])
               .merge(
                 Patient.joins(<<-SQL)
            INNER JOIN encounter test ON test.voided = 0 AND test.patient_id = patient.patient_id
            INNER JOIN obs visit ON visit.voided = 0 AND visit.person_id = person.person_id
                 SQL
               )
               .where(
                 visit: { concept_id: concept('Visit type').concept_id,
                          value_coded: concept('Self test distribution').concept_id },
                 encounter: {
                   encounter_datetime: @start_date..@end_date,
                   encounter_type: EncounterType.find_by_name('ITEMS GIVEN')
                 },
                 program: { program_id: Program.find_by_name('HTC PROGRAM').id }
               )
      end
    end
  end
end

class ObsValueScopeRevised
  def self.call(query, indicators)
    indicators.map do |indicator|
      ActiveRecord::Base.connection.select_all(\
        ObsValueScope.call(model: query, name: indicator[:name], \
                           concept: indicator[:concept], value: indicator[:value] || 'value_coded', \
                           join: indicator[:join], max: indicator[:max]).select('person.gender, person.person_id, person.birthdate, encounter.encounter_datetime, person.person_id').group(:patient_id).to_sql
      )
    end.flat_map { |arr| arr }
              .group_by { |hash| hash['person_id'] }
              .transform_values { |group| group.reduce(&:merge) }
              .values
  end
end

class ObsValueScope
  QUERY_STRING =
    <<~SQL
      %<join>s JOIN (
        SELECT %<value>s, person_id
        FROM obs
        WHERE obs.voided = 0 AND obs.concept_id = %<concept>s
      ) AS %<name>s ON %<name>s.person_id = person.person_id
    SQL

  # QUERY_STRING =
  #   <<~SQL
  #     %<join>s JOIN obs %<name>s ON %<name>s.person_id = encounter.patient_id
  #     AND %<name>s.voided = 0
  #     AND %<name>s.concept_id = %<concept>s
  #   SQL

  def self.call(model:, name:, concept:, value: 'value_coded', join: 'INNER', max: false)
    query = model
    unless [name.class, concept.class].include?(Array)
      query = query.joins(format(QUERY_STRING,
                                 join:,
                                 name:,
                                 concept: ConceptName.find_by_name(concept).concept_id,
                                 value:))

      return query.select(max ? "MAX(#{name}.#{value}) AS #{name}" : "#{name}.#{value} AS #{name}")
    end

    construct_query(model, name, concept, value, join, max)
  end

  def self.construct_query(model, name, concepts, value, join, max)
    query = model
    concepts.each_with_index do |concept, index|
      query = query.joins(format(QUERY_STRING,
                                 join:,
                                 name: name[index],
                                 concept: ConceptName.find_by_name(concept).concept_id,
                                 value:))
      query = query.select(max ? "MAX(#{name[index]}.#{value}) AS #{name[index]}" : "#{name[index]}.#{value} AS #{name[index]}")
    end
    query
  end
end

# rubocop:enable Style/Documentation, Style/MultilineBlockChain, Layout/LineLength, Metrics/AbcSize, Metrics/ModuleLength, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/BlockLength, Metrics/ParameterLists
