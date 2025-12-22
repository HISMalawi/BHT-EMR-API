# frozen_string_literal: true

# HTS Service
module HtsService
  # Dashbiard Class
  class Dashboard
    def self.daily_statistics(start_date, _end_date)
      art = Observation.joins('INNER JOIN concept_name ON concept_name.concept_id = obs.concept_id')
                       .joins('INNER JOIN encounter ON encounter.encounter_id = obs.encounter_id')
                       .where(obs: { value_text: 'ART' }, encounter: { program_id: 18 }, concept_name: { name: 'Referrals ordered' })
                       .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(start_date))
                       .count

      booked = Observation.joins('INNER JOIN concept_name ON concept_name.concept_id = obs.concept_id')
                          .joins('INNER JOIN encounter ON encounter.encounter_id = obs.encounter_id')
                          .where(encounter: { program_id: 18 }, concept_name: { name: 'ART visit' })
                          .where('obs.value_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(start_date))
                          .count

      tested = Observation.joins('INNER JOIN concept_name ON concept_name.concept_id = obs.concept_id')
                          .joins('INNER JOIN encounter ON encounter.encounter_id = obs.encounter_id')
                          .where(encounter: { program_id: 18 }, concept_name: { name: 'ART visit' }, obs: { value_datetime: start_date })
                          .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(start_date))
                          .count

      [{
        hts_registered: PatientProgram.where(program_id: 18).count,
        enrolled_on_art: art,
        booked_appointments: booked,
        tested_appointments: tested
      }]
    end

def self.dashboard_stats(filters)
  # Get unique patients with conclusive results
 today = Date.today

visit_scheduled_today = Observation
  .where(concept_id: 5096, value_datetime: today.beginning_of_day..today.end_of_day)
  .distinct
  .count(:person_id)

  concepts = {
    9774  => "Yes",       # HIV
    223   => "Positive",  # syphilis
    10052 => "Positive",  # hepatitis B
    10051 => "Positive"   # hepatitis C
  }

  clients_with_conclusive_results = Observation
    .where(
      concepts.map { |concept_id, value| "(concept_id = #{concept_id} AND value_text = '#{value}')" }.join(" OR ")
    )
    .distinct
    .count(:person_id)

  # Get unique patients referred to ART
  clients_referred_to_ART = Observation
    .where('value_text = ? AND concept_id = ?', 'Yes', 3576)
    .distinct
    .count(:person_id)

  clients_tested_today = Encounter
    .where('program_id = ? AND DATE(encounter_datetime) = ? AND encounter_type = ?', 37, Date.today, 32)
    .distinct
    .count(:patient_id)

  {
    total_clients: Encounter.where(program_id: 37).distinct.count(:patient_id),
    clients_with_conclusive_results: clients_with_conclusive_results,
    clients_tested_today: clients_tested_today,
    clients_referred_to_ART: clients_referred_to_ART,
    visit_scheduled_today:visit_scheduled_today,
    patient_data: find_orders(filters)
  }
end

def self.find_orders(filters)
  date = filters.delete(:date)

  # Use the new SQL query to get patients with orders without results
  query = <<-SQL
    SELECT DISTINCT
      p.person_id AS patient_id,
      CONCAT_WS(' ', pn.given_name, pn.middle_name, pn.family_name) AS patient_name,
      TIMESTAMPDIFF(YEAR, p.birthdate, CURDATE()) AS patient_age,
      p.gender AS patient_gender,
      COUNT(DISTINCT lo.order_id) AS total_orders,
      MAX(lo.start_date) AS most_recent_order_date,
      COUNT(DISTINCT CASE WHEN orders_without_results.order_id IS NOT NULL THEN lo.order_id END) AS orders_without_results,
      
      -- Concatenate programs ONLY for orders without results
      GROUP_CONCAT(DISTINCT CASE WHEN orders_without_results.order_id IS NOT NULL THEN prog.program_id END ORDER BY prog.program_id SEPARATOR ', ') AS program_ids,
      GROUP_CONCAT(DISTINCT CASE WHEN orders_without_results.order_id IS NOT NULL THEN prog.name END ORDER BY prog.name SEPARATOR ', ') AS program_names
      
    FROM orders lo
    INNER JOIN person p ON p.person_id = lo.patient_id AND p.voided = 0
    INNER JOIN order_type ot ON ot.order_type_id = lo.order_type_id AND ot.retired = 0
    LEFT JOIN person_name pn ON pn.person_id = p.person_id AND pn.voided = 0
    LEFT JOIN encounter e ON e.encounter_id = lo.encounter_id AND e.voided = 0
    LEFT JOIN program prog ON prog.program_id = e.program_id AND prog.retired = 0
    LEFT JOIN (
      SELECT DISTINCT o.order_id
      FROM orders o
      LEFT JOIN obs test_obs ON test_obs.order_id = o.order_id AND test_obs.voided = 0
      LEFT JOIN obs result_obs ON result_obs.obs_group_id = test_obs.obs_id AND result_obs.voided = 0
      WHERE o.voided = 0
      GROUP BY o.order_id
      HAVING COUNT(result_obs.obs_id) = 0
    ) AS orders_without_results ON orders_without_results.order_id = lo.order_id
    WHERE lo.voided = 0
      AND lo.order_type_id = 9
  SQL

  # Add dynamic filters if provided
  where_conditions = []
  bind_values = []

  if filters[:patient_id]
    where_conditions << "p.person_id = ?"
    bind_values << filters[:patient_id]
  end

  if filters[:accession_number]
    where_conditions << "lo.accession_number = ?"
    bind_values << filters[:accession_number]
  end

  unless where_conditions.empty?
    query += " AND #{where_conditions.join(' AND ')}"
  end

  query += <<-SQL
    GROUP BY p.person_id, pn.given_name, pn.middle_name, pn.family_name, p.birthdate, p.gender
    HAVING COUNT(DISTINCT CASE WHEN orders_without_results.order_id IS NOT NULL THEN lo.order_id END) > 0
  SQL

  # Apply date filter to the HAVING clause if needed
  if date
    query += " AND MAX(lo.start_date) = ?"
    bind_values << date
  end

  query += " ORDER BY most_recent_order_date DESC"

  # Execute the query
  results = if bind_values.any?
              ActiveRecord::Base.connection.select_all(
                ActiveRecord::Base.send(:sanitize_sql_array, [query] + bind_values)
              )
            else
              ActiveRecord::Base.connection.select_all(query)
            end

  # Map results to the expected format
  results.map do |row|
    ActiveSupport::HashWithIndifferentAccess.new(
      {
        patient_id: row['patient_id'],
        patient_name: row['patient_name'],
        patient_age: row['patient_age'],
        patient_gender: row['patient_gender'],
        total_orders: row['total_orders'],
        most_recent_order_date: row['most_recent_order_date'],
        orders_without_results: row['orders_without_results'],
        program_ids: row['program_ids'],
        program_names: row['program_names']
      }
    )
  end
end

  end
end
