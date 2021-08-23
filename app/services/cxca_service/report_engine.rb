
module CXCAService
  class ReportEngine

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
