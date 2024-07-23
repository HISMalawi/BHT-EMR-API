# frozen_string_literal: true

module TbService
  module Reports
    module MdrCaseFinding # rubocop:disable Style/Documentation
      class << self
        def format_report(indicator:, report_data:, **_kwargs)
          {
            indicator:,
            data: report_data
          }
        end

        def patients_aged_fourteen_and_below(start_date, end_date)
          query = mdr_patient_query.ref(start_date, end_date)
          to_result(query.age_range(0, 15), start_date, end_date)
        end

        def patients_aged_fourteen_and_above(start_date, end_date)
          query = mdr_patient_query.ref(start_date, end_date)
          to_result(query.age_range(15, 120), start_date, end_date)
        end

        def new_dr_cases(start_date, end_date)
          query = mdr_patient_query.ref(start_date, end_date)
          to_result(query.new_patient, start_date, end_date)
        end

        def previously_treated_with_firstline_drugs(start_date, end_date)
          query = mdr_patient_query.ref(start_date, end_date)
          persons = query.present? ? query.map(&:patient_id) : []
          on_firstline = mdr_diagnosis_query.previously_on_firstline_treatment(start_date)
          to_result(on_firstline.where(patient_id: persons), start_date, end_date)
        end

        def previously_treated_for_tb_drug_resistance(start_date, end_date)
          query = mdr_patient_query.ref(start_date, end_date)
          persons = query.present? ? query.map(&:patient_id) : []
          on_secondline = mdr_diagnosis_query.previously_on_secondline_treatment(start_date)
          to_result(on_secondline.where(patient_id: persons), start_date, end_date)
        end

        def patients_on_individualised_regimen(start_date, end_date)
          query = mdr_patient_query.ref(start_date, end_date)
          to_result(query.regimen('Individualised regimen'), start_date, end_date)
        end

        def patients_on_short_regimen(start_date, end_date)
          query = mdr_patient_query.ref(start_date, end_date)
          to_result(query.regimen('Shorter intensive phase regimen'), start_date, end_date)
        end

        def patients_on_standardised_regimen(start_date, end_date)
          query = mdr_patient_query.ref(start_date, end_date)
          to_result(query.regimen('Standard intensive phase regimen'), start_date, end_date)
        end

        def dr_male_patients(start_date, end_date)
          query = mdr_patient_query.ref(start_date, end_date)
          to_result(query.male, start_date, end_date)
        end

        def dr_female_patients(start_date, end_date)
          query = mdr_patient_query.ref(start_date, end_date)
          to_result(query.female, start_date, end_date)
        end

        def dr_hiv_positive_patients(start_date, end_date)
          query = mdr_patient_query.ref(start_date, end_date)
          to_result(query.hiv_status('Positive'), start_date, end_date)
        end

        def dr_hiv_negative_patients(start_date, end_date)
          query = mdr_patient_query.ref(start_date, end_date)
          to_result(query.hiv_status('Negative'), start_date, end_date)
        end

        def dr_patients_on_art(start_date, end_date)
          query = mdr_patient_query.ref(start_date, end_date)
          to_result(query.on_art('Yes'), start_date, end_date)
        end

        def dr_patients_not_on_art(start_date, end_date)
          query = mdr_patient_query.ref(start_date, end_date)
          to_result(query.on_art('No'), start_date, end_date)
        end

        private

        def to_result(query, start_date, end_date)
          clinical = mdr_diagnosis_query.clinical_mdr(start_date, end_date)
          mdr_confirmed = mdr_diagnosis_query.confirmed_mdr(start_date, end_date)
          rif_confirmed = mdr_diagnosis_query.confirmed_rif(start_date, end_date)

          clinical_result = query.where(patient_id: clinical.present? ? clinical.map(&:patient_id) : [])
          mdr_confirmed_result = query.where(patient_id: mdr_confirmed.present? ? mdr_confirmed.map(&:patient_id) : [])
          rif_confirmed_result = query.where(patient_id: rif_confirmed.present? ? rif_confirmed.map(&:patient_id) : [])

          {
            clinical: {
              male: clinical_result.joins(:person).where(person: { gender: 'M' })&.map(&:patient_id),
              female: clinical_result.joins(:person).where(person: { gender: 'F' })&.map(&:patient_id)
            },
            mdr_confirmed: {
              male: mdr_confirmed_result.joins(:person).where(person: { gender: 'M' })&.map(&:patient_id),
              female: mdr_confirmed_result.joins(:person).where(person: { gender: 'F' })&.map(&:patient_id)
            },
            rif_confirmed: {
              male: rif_confirmed_result.joins(:person).where(person: { gender: 'M' })&.map(&:patient_id),
              female: rif_confirmed_result.joins(:person).where(person: { gender: 'F' })&.map(&:patient_id)
            },
            total: {
              male: query.joins(:person).where(person: { gender: 'M' })&.map(&:patient_id),
              female: query.joins(:person).where(person: { gender: 'F' })&.map(&:patient_id)
            }
          }
        end

        def mdr_patient_query
          TbService::TbQueries::MdrPatientQuery.new
        end

        def mdr_diagnosis_query
          TbService::TbQueries::MdrQuery.new
        end
      end
    end
  end
end
