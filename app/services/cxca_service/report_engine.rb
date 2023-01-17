module CXCAService
  class ReportEngine
    REPORT_NAMES = {
      'SCREENED FOR CXCA' => CXCAService::Reports::Moh::ScreenedForCXCA,
      'SCREENED FOR CXCA DISAGGREGATED BY HIV STATUS' => CXCAService::Reports::Moh::ScreenedForCXCADisaggregatedByHivStatus,
      'CXCA SCREENING RESULTS' => CXCAService::Reports::Moh::CXCAScreeningResults,
      'CANCER SUSPECTS' => CXCAService::Reports::Moh::CancerSuspects,
      'CLIENTS TREATED' => CXCAService::Reports::Moh::ClientTreated,
      'TREATMENT OPTIONS' => CXCAService::Reports::Moh::TreatmentOptions,
      'REFERRAL REASONS' => CXCAService::Reports::Moh::ReferralReasons,
      'VISIT REASONS' => CXCAService::Reports::Clinic::VisitReasons,
      'BOOKED CLIENTS FROM ART' => CXCAService::Reports::Clinic::BookedClientsFromArt,
      'BOOKED CLIENTS FROM ART RAW DATA' => CXCAService::Reports::Clinic::BookedClientsFromArtRawData,
      'CC ALL QUESTIONS' => CXCAService::Reports::Pepfar::CcAllQuestions,
      'CC TYPE OF SCREEN' => CXCAService::Reports::Pepfar::CcAllQuestions,
      'CC SCREEN RESULT' => CXCAService::Reports::Pepfar::CcAllQuestions,
      'CC TYPE OF TREATMENT' => CXCAService::Reports::Pepfar::CcAllQuestions,
      'CC BASIC RESULT' => CXCAService::Reports::Pepfar::CcBasicResult
    }.freeze

    def reports(start_date, end_date, name)
      name = name.upcase
      case name
      when 'CC ALL QUESTIONS'
        REPORT_NAMES[name].new(start_date: start_date,
                               end_date: end_date).general_report
      when 'CC TYPE OF SCREEN'
        REPORT_NAMES[name].new(start_date: start_date,
                               end_date: end_date).visit_report

      when 'CC SCREEN RESULT'
        REPORT_NAMES[name].new(start_date: start_date,
                               end_date: end_date).screening_result_report

      when 'CC TYPE OF TREATMENT'
        REPORT_NAMES[name].new(start_date: start_date,
                               end_date: end_date).treatment_resport
      else
        REPORT_NAMES[name].new(start_date: start_date, end_date: end_date).data
      end
    end

    def dashboard_stats(date)
      test_performed date
    end

    private

    def test_performed(date)
      cxca_tests = ['VIA', 'PAP Smear', 'HPV DNA', 'Speculum Exam']
      concept_names = ConceptName.where(name: cxca_tests).map { |c| [c.name, c.concept_id] }
      screened_method = ConceptName.find_by_name 'CxCa screening method'
      tests = {}

      concept_names.each do |name, concept_id|
        tests[name] = Observation.where(value_coded: concept_id,
                                        concept_id: screened_method.concept_id,
                                        obs_datetime: [date.to_date.strftime('%Y-%m-%d 00:00:00')..
          date.to_date.strftime('%Y-%m-%d 23:59:59')]).count
      end

      tests
    end
  end
end
