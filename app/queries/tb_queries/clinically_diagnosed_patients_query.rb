# frozen_string_literal: true

module TBQueries
  class ClinicallyDiagnosedPatientsQuery
    def initialize(relation = Patient.all)
      @relation = relation
      @program = program('TB Program')
    end

    def with_pulmonary_tuberculosis(ids, start_date, end_date)
      type = encounter_type('Diagnosis')
      concept = 1549 # duplicate concepts preventing dynamic resolution
      Patient.select(:patient_id).distinct\
             .joins(encounters: :observations).where(encounter: { encounter_type: type,
                                                                  program_id: @program,
                                                                  encounter_datetime: start_date..end_date },
                                                     obs: { value_coded: concept,
                                                            person_id: ids })
    end
  end
end
