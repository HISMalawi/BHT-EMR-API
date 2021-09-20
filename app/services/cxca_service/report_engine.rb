module CXCAService
  class ReportEngine

    REPORT_NAMES = {
      'SCREENED FOR CXCA' => CXCAService::Reports::Moh::ScreenedForCxca,
      'SCREENED FOR CXCA DISAGGREGATED BY HIV STATUS' => CXCAService::Reports::Moh::ScreenedForCxcaDisaggregatedByHivStatus,
      'CXCA SCREENING RESULTS' => CXCAService::Reports::Moh::CxcaScreeningResults,
      'CANCER SUSPECTS' => CXCAService::Reports::Moh::CancerSuspects,
      'CLIENTS TREATED' => CXCAService::Reports::Moh::ClientTreated,
      'TREATMENT OPTIONS' => CXCAService::Reports::Moh::TreatmentOptions,
      'REFERRAL REASONS' => CXCAService::Reports::Moh::ReferralReasons,
      'VISIT REASONS' => CXCAService::Reports::Clinic::VisitReasons
    }.freeze

    def reports(start_date, end_date, name)
      REPORT_NAMES[name].new(start_date: start_date, end_date: end_date).data
    end

    def dashboard_stats(date)
      return test_performed date
    end

    private

    def test_performed(date)
      cxca_tests = ["VIA","PAP Smear","HPV DNA","Speculum Exam"]
      concept_names = ConceptName.where(name: cxca_tests).map{|c|[c.name, c.concept_id]}
      screened_method = ConceptName.find_by_name 'CxCa screening method'
      tests = {}

      concept_names.each do |name, concept_id|
        tests[name] = Observation.where(value_coded: concept_id,
          concept_id: screened_method.concept_id,
          obs_datetime: [date.to_date.strftime('%Y-%m-%d 00:00:00')..
          date.to_date.strftime('%Y-%m-%d 23:59:59')]).count
      end

      return tests
    end

  end
end
