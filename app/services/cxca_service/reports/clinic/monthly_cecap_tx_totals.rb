module CXCAService::Reports::Clinic
  class MonthlyCecapTxTotals
    include Utils

    attr_accessor :start_date, :end_date, :report

    CxCa_PROGRAM = program "CxCa program"

    def initialize(start_date:, end_date:)
      @start_date = start_date.to_date.beginning_of_day
      @end_date = end_date.to_date.end_of_day
      @report = {}
    end

    def data
      init_report
    end

    private

    def init_report
      query = fetch_query
      report["total_cyrotherapy"] = query.select { |q| q["treatment"].to_s.downcase == "cryotherapy" }.map { |t| t["person_id"] }.uniq
      report["total_thermocoagulation"] = query.select { |q| q["treatment"].to_s.downcase == "thermocoagulation" }.map { |t| t["person_id"] }.uniq
      report["total_leep"] = query.select { |q| q["treatment"].to_s.downcase == "leep" }.map { |t| t["person_id"] }.uniq
      report["total_number_same_day_tx"] = query.select { |q| q["tx_option"] == "Same day treatment" }.map { |t| t["person_id"] }.uniq
      report["total_via_deffered"] = query.select { |d| d["tx_option"] == "Postponed treatment" && (d["via_result"].to_s.downcase == "VIA positive" || d["screening_results"] == "VIA positive") }.map { |t| t["person_id"] }.uniq
      report["total_via_reffered"] = query.select { |d| d["tx_option"] == "Referral" && (d["via_result"].to_s.downcase == "VIA positive" || d["screening_results"] == "VIA positive") }.map { |t| t["person_id"] }.uniq
      report["suspects_reffered"] = query.select { |d| d["tx_option"] == "Referral" && d["via_result"].to_s.downcase == "Suspect cancer" }.map { |t| t["person_id"] }.uniq
      report["total_reffered"] = query.select { |d| d["tx_option"] == "Referral" }.map { |t| t["person_id"] }.uniq
      report
    end

    def fetch_query
      Person.connection.select_all(
        Person.joins(patient: :encounters)
          .where(encounter: { program_id: CxCa_PROGRAM.id, encounter_datetime: @start_date..@end_date })
          .joins(<<~SQL)
            LEFT JOIN obs reason_for_visit ON reason_for_visit.person_id = person.person_id
            AND reason_for_visit.voided = 0
            AND reason_for_visit.concept_id = #{concept("Reason for visit").concept_id}
            LEFT JOIN concept_name reason_name ON reason_name.concept_id = reason_for_visit.value_coded
            AND reason_name.voided = 0
            LEFT JOIN obs via_results ON via_results.person_id = person.person_id
            AND via_results.voided = 0
            AND via_results.concept_id = 9514
            LEFT JOIN concept_name result_name ON result_name.concept_id = via_results.value_coded
            AND result_name.voided = 0
            LEFT JOIN obs treatment_option ON treatment_option.person_id = person.person_id
            AND treatment_option.voided = 0
            AND treatment_option.concept_id = #{concept("Directly observed treatment option").concept_id}
            LEFT JOIN concept_name tx_option_name ON tx_option_name.concept_id = treatment_option.value_coded
            AND treatment_option.voided = 0
            LEFT JOIN obs treatment ON treatment.person_id = person.person_id
            AND treatment.voided = 0
            AND treatment.concept_id = #{concept("Treatment").concept_id}
            LEFT JOIN obs screening_results ON screening_results.person_id = person.person_id
            AND screening_results.voided = 0
            AND screening_results.concept_id = #{concept("Screening results").concept_id}
            LEFT JOIN concept_name screening_results_name ON screening_results_name.concept_id = screening_results.value_coded
            AND screening_results_name.voided = 0
          SQL
          .group("person.person_id")
          .select("disaggregated_age_group(person.birthdate, DATE('#{@end_date.to_date}')) AS age_group, person.person_id, reason_name.name AS reason_for_visit, max(treatment.value_text) AS treatment, result_name.name AS via_result, screening_results_name.name as screening_results, tx_option_name.name AS tx_option")
          .to_sql
      ).to_hash
    end
  end
end
