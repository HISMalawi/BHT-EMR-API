# frozen_string_literal: true

module CxcaService
  # ReportEngine
  class ReportEngine
    REPORT_NAMES = {
      'SCREENED FOR CXCA' => CxcaService::Reports::Moh::ScreenedForCxca,
      'SCREENED FOR CXCA DISAGGREGATED BY HIV STATUS' => CxcaService::Reports::Moh::ScreenedForCxcaDisaggregatedByHivStatus,
      'CXCA SCREENING RESULTS' => CxcaService::Reports::Moh::CxcaScreeningResults,
      'CANCER SUSPECTS' => CxcaService::Reports::Moh::CancerSuspects,
      'CLIENTS TREATED' => CxcaService::Reports::Moh::ClientTreated,
      'TREATMENT OPTIONS' => CxcaService::Reports::Moh::TreatmentOptions,
      'REFERRAL REASONS' => CxcaService::Reports::Moh::ReferralReasons,
      'VISIT REASONS' => CxcaService::Reports::Clinic::VisitReasons,
      'BOOKED CLIENTS FROM ART' => CxcaService::Reports::Clinic::BookedClientsFromArt,
      'BOOKED CLIENTS FROM ART RAW DATA' => CxcaService::Reports::Clinic::BookedClientsFromArtRawData,
      'CC ALL QUESTIONS' => CxcaService::Reports::Pepfar::CcAllQuestions,
      'CC TYPE OF SCREEN' => CxcaService::Reports::Pepfar::CcAllQuestions,
      'CC SCREEN RESULT' => CxcaService::Reports::Pepfar::CcAllQuestions,
      'CC TYPE OF TREATMENT' => CxcaService::Reports::Pepfar::CcAllQuestions,
      'CC BASIC RESULT' => CxcaService::Reports::Pepfar::CcBasicResult,
      'CXCA REASON FOR VISIT' => CxcaService::Reports::Moh::ReasonForVisit,
      'CXCA TX' => CxcaService::Reports::Pepfar::CxcaTx,
      'CXCA SCRN' => CxcaService::Reports::Pepfar::CxcaScrn,
      'CLINIC CXCA SCRN' => CxcaService::Reports::Clinic::CxcaScrn,
      'MONTHLY CECAP TX' => CxcaService::Reports::Clinic::MonthlyCecapTx,
      'MONTHLY SCREEN' => CxcaService::Reports::Clinic::MonthlyScreenReport,
      'REASON FOR NOT SCREENING REPORT' => CxcaService::Reports::Clinic::ReasonForNotScreeningReport
    }.freeze

    def reports(start_date, end_date, name, **kwargs)
      name = name.upcase
      case name
      when 'CC ALL QUESTIONS'
        REPORT_NAMES[name].new(start_date:,
                               end_date:).general_report
      when 'CC TYPE OF SCREEN'
        REPORT_NAMES[name].new(start_date:,
                               end_date:).visit_report

      when 'CC SCREEN RESULT'
        REPORT_NAMES[name].new(start_date:,
                               end_date:).screening_result_report

      when 'CC TYPE OF TREATMENT'
        REPORT_NAMES[name].new(start_date:,
                               end_date:).treatment_resport
      else
        REPORT_NAMES[name].new(start_date:, end_date:, **kwargs).data
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
