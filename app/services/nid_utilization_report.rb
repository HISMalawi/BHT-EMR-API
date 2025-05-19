# frozen_string_literal: true

# This class is responsible for generating the NID Utilization Report
class NidUtilizationReport
  include ArtService::Reports::Pepfar::Utils
  include ModelUtils

  attr_accessor :start_date, :end_date, :program_id, :report

  def initialize(start_date:, end_date:, program_id:, **_kwargs)
    @start_date = ActiveRecord::Base.connection.quote(start_date)
    @end_date = ActiveRecord::Base.connection.quote(end_date)
    @program_id = program_id
  end

  def find_report
    return [] if start_date.blank? || end_date.blank?

    @report = init_report
    addittional_groups
    process_data
    flatten_the_report
  end

  private

  GENDER = %w[M F].freeze

  def init_report
    pepfar_age_groups.each_with_object({}) do |age_group, report|
      report[age_group] = GENDER.each_with_object({}) do |gender, age_group_report|
        age_group_report[gender] = initialize_gender_metrics
      end
    end
  end

  def addittional_groups
    report['All'] = {}
    %w[Male FP FNP FBf].each do |key|
      report['All'][key] = initialize_gender_metrics
    end
  end

  def initialize_gender_metrics
    {
      total_visits: [],
      nid_clients: [],
      new_nid: []
    }
  end

  def flatten_the_report
    result = []
    report.each do |age_group, age_group_data|
      age_group_data.each_key do |gender|
        result << process_age_group_report(age_group, gender, age_group_data[gender])
      end
    end

    new_group = pepfar_age_groups.map { |age_group| age_group }
    new_group << 'All'
    gender_scores = { 'Female' => 0, 'Male' => 1, 'FNP' => 3, 'FP' => 2, 'FBf' => 4 }
    result_scores = result.sort_by do |item|
      gender_score = gender_scores[item[:gender]]
      age_group_score = new_group.index(item[:age_group])
      [gender_score, age_group_score]
    end
    # remove all unknown age groups
    result_scores.reject { |item| item[:age_group].match?(/unknown/i) }
  end

  def process_age_group_report(age_group, gender, age_group_data)
    {
      age_group: age_group,
      gender: gender == 'F' ? 'Female' : (gender == 'M' ? 'Male' : gender), 
      **age_group_data
    }
  end

  def process_data
    fetch_data.each do |row|
      age_group = row['age_group']
      gender = row['gender']
      next if age_group.blank?
      next if gender.blank?
      next unless GENDER.include?(gender)
      next unless pepfar_age_groups.include?(age_group)

      report[age_group.to_s][gender.to_s][:total_visits] << row['patient_id']
      report[age_group.to_s][gender.to_s][:nid_clients] << row['patient_id'] if row['nid_status'] != 'No NID'
      report[age_group.to_s][gender.to_s][:new_nid] << row['patient_id'] if row['nid_status'] == 'NEW NID'

      process_aggreggation_rows(report:, row:, age_group:, gender:)
    end
  end

  def process_aggreggation_rows(report:, row:, age_group:, gender:)
    maternal_status = row['maternal_status']
    maternal_status_valid = row['maternal_status_valid']

    if gender == 'M'
      report['All']['Male'][:total_visits] << row['patient_id']
      report['All']['Male'][:nid_clients] << row['patient_id'] if row['nid_status'] != 'No NID'
      report['All']['Male'][:new_nid] << row['patient_id'] if row['nid_status'] == 'NEW NID'
    elsif maternal_status&.match?(/pregnant/i) && maternal_status_valid
      report['All']['FP'][:total_visits] << row['patient_id']
      report['All']['FP'][:nid_clients] << row['patient_id'] if row['nid_status'] != 'No NID'
      report['All']['FP'][:new_nid] << row['patient_id'] if row['nid_status'] == 'NEW NID'
    elsif maternal_status&.match?(/breastfeeding/i) && maternal_status_valid
      report['All']['FBf'][:total_visits] << row['patient_id']
      report['All']['FBf'][:nid_clients] << row['patient_id'] if row['nid_status'] != 'No NID'
      report['All']['FBf'][:new_nid] << row['patient_id'] if row['nid_status'] == 'NEW NID'
    else
      report['All']['FNP'][:total_visits] << row['patient_id']
      report['All']['FNP'][:nid_clients] << row['patient_id'] if row['nid_status'] != 'No NID'
      report['All']['FNP'][:new_nid] << row['patient_id'] if row['nid_status'] == 'NEW NID'
    end
    
  end

  def fetch_data
    ActiveRecord::Base.connection.select_all <<~SQL
      SELECT p.person_id AS patient_id, UPPER(LEFT(p.gender, 1)) gender,
        disaggregated_age_group(p.birthdate, #{end_date}) age_group,
        CASE
          WHEN MAX(pi.date_created) IS NULL THEN 'No NID'
          WHEN MAX(pi.date_created) >= #{start_date} THEN 'NEW NID'
          ELSE 'OLD NID'
        END AS nid_status,
        preg_or_breast.name AS maternal_status,
        CASE
          WHEN MAX(pregnant_or_breastfeeding.obs_datetime) IS NULL THEN FALSE
          WHEN MAX(DATE(pregnant_or_breastfeeding.obs_datetime)) = MAX(DATE(e.encounter_datetime)) THEN TRUE
          ELSE FALSE
        END AS maternal_status_valid
      FROM person p
      INNER JOIN encounter e ON p.person_id = e.patient_id AND e.voided = 0 AND e.program_id = #{program_id}
      INNER JOIN encounter_type et ON e.encounter_type = et.encounter_type_id and et.retired = 0 and et.name != 'Lab'
      LEFT JOIN patient_identifier pi ON e.patient_id = pi.patient_id AND pi.identifier_type = 28 and pi.voided = 0
      LEFT JOIN obs pregnant_or_breastfeeding ON pregnant_or_breastfeeding.person_id = e.patient_id
        AND pregnant_or_breastfeeding.concept_id IN (SELECT concept_id FROM concept_name WHERE name IN ('Breast feeding?', 'Breast feeding', 'Breastfeeding', 'Is patient pregnant?', 'patient pregnant') AND voided = 0)
        AND pregnant_or_breastfeeding.voided = 0
        AND pregnant_or_breastfeeding.value_coded = #{concept_name('Yes').concept_id}
        AND pregnant_or_breastfeeding.obs_datetime BETWEEN #{start_date} AND #{end_date}
      LEFT JOIN concept_name preg_or_breast ON preg_or_breast.concept_id = pregnant_or_breastfeeding.concept_id AND preg_or_breast.voided = 0
      WHERE p.voided = 0 AND e.encounter_datetime BETWEEN #{start_date} AND #{end_date}
      GROUP BY p.person_id
    SQL
  end
end