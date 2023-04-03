module CXCAService::Reports::Pepfar
  class CxcaTx
    attr_reader :start_date, :end_date, :report
    include Utils

    CxCa_PROGRAM = program "CxCa program"

    TX_GROUPS = {
      first_time_screened: ["Initial Screening", "Referral"],
      rescreened_after_prev_visit: ["Subsequent screening"],
      post_treatment_followup: ["One year subsequent check-up after treatment", "Problem visit after treatment"],
    }.freeze

    TREATMENTS = %i[thermocoagulation cryotherapy leep].freeze

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
      query = fetch_query.to_hash
      pepfar_age_groups.collect do |age_group|
        row = {}
        row["age_group"] = age_group
        TX_GROUPS.each do |(name, values)|
          screened = query.select { |q| q["reason_for_visit"].in?(values) && q["age_group"] == age_group }
          TREATMENTS.each do |treatment|
            treated = screened.select { |s| s["treatment"].to_s.downcase == treatment.to_s.downcase }
            row[name] ||= {}
            row[name][treatment] = treated.map { |t| t["person_id"] }.uniq
          end
        end
        row
      end
    end

    def fetch_query
      Person.connection.select_all(
        Person.joins(patient: :encounters)
          .where(encounter: { program_id: CxCa_PROGRAM.id, encounter_datetime: @start_date..@end_date })
          .joins(<<~SQL)
            LEFT JOIN obs reason_for_visit ON reason_for_visit.person_id = person.person_id
            AND reason_for_visit.voided = 0
            AND reason_for_visit.concept_id = #{concept("Reason for visit").concept_id}
            LEFT JOIN obs treatment ON treatment.person_id = person.person_id
            AND treatment.voided = 0
            AND treatment.concept_id = #{concept("Treatment").concept_id}
            INNER JOIN concept_name reason_name ON reason_name.concept_id = reason_for_visit.value_coded
            AND reason_name.voided = 0
          SQL
          .group("person.person_id")
          .select("disaggregated_age_group(person.birthdate, DATE('#{@end_date.to_date}')) AS age_group, person.person_id, reason_name.name AS reason_for_visit, treatment.value_text AS treatment")
          .to_sql
      )
    end
  end
end
