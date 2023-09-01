module CXCAService::Reports::Moh
  class ReasonForVisit
    attr_accessor :start_date, :end_date

    CxCa_PROGRAM = program "CxCa program"

    def initialize(start_date:, end_date:)
      @start_date = start_date.to_date.beginning_of_day
      @end_date = end_date.to_date.end_of_day
    end

    def data
      init_report
    end

    private

    def init_report
      report = {}
      %i[initial_screening referral postponed one_year_after_sub_visit subsequent problem_visit_after_treatment].each { |key| report[key] = [] }
      Person.joins(patient: :encounters)
        .where(encounter: { program_id: CxCa_PROGRAM.id, encounter_datetime: @start_date..@end_date })
        .joins(<<~SQL)
          INNER JOIN obs reason_for_visit ON reason_for_visit.person_id = person.person_id
          AND reason_for_visit.voided = 0
          AND reason_for_visit.concept_id = #{concept("Reason for visit").concept_id}
          INNER JOIN concept_name on concept_name.concept_id = reason_for_visit.value_coded
        SQL
        .group("person.person_id")
        .select("person.person_id, concept_name.name as reason")
        .each do |person|
        report[:initial_screening].push(person.person_id) if person.reason == "Initial Screening"
        report[:referral].push(person.person_id) if person.reason == "Referral"
        report[:postponed].push(person.person_id) if person.reason == "Postponed treatment"
        report[:one_year_after_sub_visit].push(person.person_id) if person.reason == "One year subsequent check-up after treatment"
        report[:subsequent].push(person.person_id) if person.reason == "Subsequent screening"
        report[:problem_visit_after_treatment].push(person.person_id) if person.reason == "Problem visit after treatment"
      end
      report
    end
  end
end
