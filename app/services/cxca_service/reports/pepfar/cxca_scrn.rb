module CXCAService::Reports::Pepfar
  class CxcaScrn
    attr_reader :start_date, :end_date, :report
    include Utils

    CxCa_PROGRAM = program "CxCa program"

    TX_GROUPS = {
      first_time_screened: ["initial screening", "referral"],
      rescreened_after_prev_visit: ["subsequent screening"],
      post_treatment_followup: ["one year subsequent check-up after treatment", "problem visit after treatment"],
    }.freeze

    CxCa_TX_OUTCOMES = {
      positive: ["via positive", "hpv positive", "pap smear abnormal", "visible lesion"],
      negative: ["via negative", "hpv negative", "pap smear normal", "no visible lesion", "other gynae"],
      suspected: ["suspect cancer"],
    }

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
          screened = query.select { |q| q["reason_for_visit"]&.strip&.downcase&.in?(values) && q["age_group"] == age_group }
          row[name] = {}
          CxCa_TX_OUTCOMES.each do |(outcome, values)|
            row[name][outcome] = screened.select { |s| s["treatment"]&.strip&.downcase&.in?(values) }.map { |t| t["person_id"] }.uniq
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
            AND treatment.concept_id = #{concept("Screening results").concept_id}
            LEFT JOIN concept_name reason_name ON reason_name.concept_id = reason_for_visit.value_coded
            AND reason_name.voided = 0
            LEFT JOIN concept_name screening_name ON screening_name.concept_id = treatment.value_coded
            AND screening_name.voided = 0
            AND screening_name.name IS NOT NULL
          SQL
          .group("person.person_id")
          .select("disaggregated_age_group(person.birthdate, DATE('#{@end_date.to_date}')) AS age_group, person.person_id, reason_name.name AS reason_for_visit, screening_name.name AS treatment")
          .to_sql
      )
    end
  end
end
