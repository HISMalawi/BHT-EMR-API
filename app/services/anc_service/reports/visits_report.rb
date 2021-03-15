# frozen_string_literal: true

class ANCService::Reports::VisitsReport
  include ModelUtils

  def initialize(name:, type:, start_date:, end_date:)
    @name = name
    @type = type
    @start_date = start_date.to_date
    @end_date = end_date.to_date
  end

  def current_visit_statistics

    @types = ["1", "2", "3", "4", ">5"]

    @me = {"1" => 0, "2" => 0, "3" => 0, "4" => 0, ">5" => 0}

    @today = {"1" => 0, "2" => 0, "3" => 0, "4" => 0, ">5" => 0}

    @year = {"1" => 0, "2" => 0, "3" => 0, "4" => 0, ">5" => 0}

    @ever = {"1" => 0, "2" => 0, "3" => 0, "4" => 0, ">5" => 0}

    anc_visit_type = EncounterType.find_by name: "ANC VISIT TYPE"

    reason_for_visit = ConceptName.find_by name: "Reason for visit"

    results = Encounter.joins([:observations])
        .where(["encounter_type = ? AND concept_id = ?
          AND (DATE(encounter_datetime) BETWEEN (?) AND (?))",
            anc_visit_type.id, reason_for_visit.concept_id,
            @start_date.strftime("%Y-%m-%d 00:00:00"),
            @start_date.strftime("%Y-%m-%d 23:59:59")])
        .group(["person_id"])
        .select(["encounter.creator, encounter_datetime AS date,
            MAX(value_numeric) form_id"])

    results.each do |data|

      cat = data.form_id.to_i
      #next unless Array(cat).include?@me.keys

      cat = cat > 4 ? ">5" : cat.to_s

      if ((data.creator.to_i == User.current.id.to_i))# && (Array(cat).include?@me.keys))

        @me["#{cat}"] += 1

      end

      #if ((Array(cat).include?@today.keys))
        @today["#{cat}"] += 1
      #end


    end

    Encounter.joins([:observations])
        .where(["encounter_type = ? AND concept_id = ?
            AND (DATE(encounter_datetime) BETWEEN (?) AND (?))",
            anc_visit_type.id, reason_for_visit.concept_id,
            @start_date.beginning_of_year, @start_date.end_of_year])
        .group(["person_id"])
        .select(["encounter.creator, encounter_datetime AS date,
            MAX(value_numeric) form_id"]).each do |data|

      cat = data.form_id.to_i

      cat = cat > 4 ? ">5" : cat.to_s

      @year["#{cat}"] += 1

    end

    return {"user": @me, "today": @today, "year": @year, "ever": @ever}

  end

  def build_report
    visits = (@start_date..@end_date).each_with_object({}) do |date, visits|
      visits[date] ||= { incomplete: 0, complete: 0 }

      find_visiting_patients(date).each do |patient|
        if workflow_engine(patient, date).next_encounter
          visits[date][:incomplete] += 1
        else
          visits[date][:complete] += 1
        end
      end
    end

    save_report visits
  end

  def find_report
    current_visit_statistics
=begin
    /(@start_date..@end_date).each_with_object({}) do |date, parsed_report|
      report = fetch_report date

      parsed_values = report.values.each_with_object({}) do |report_value, parsed_values|
        parsed_values[report_value.indicator_name] = report_value.contents.to_i
      end

      return nil if parsed_values.empty?  # Force regeneration of report

      parsed_report[date] = parsed_values
    end
=end
  end

  private

  # Returns a list of patients who visited the ART clinic on given day.
  def find_visiting_patients(date)
    day_start, day_end = TimeUtils.day_bounds(date)
    Patient.find_by_sql(
      [
        'SELECT patient.* FROM patient INNER JOIN encounter USING (patient_id)
         WHERE encounter.encounter_datetime BETWEEN ? AND ?
          AND encounter.voided = 0 AND patient.voided = 0
         GROUP BY patient.patient_id',
        day_start, day_end
      ]
    )
  end

  def workflow_engine(patient, date)
    ARTService::WorkflowEngine.new patient: patient,
                                   program: hiv_program,
                                   date: date
  end

  def hiv_program
    @hiv_program ||= program('HIV Program')
  end

  def save_report(visits)
    visits.each do |date, values|
      report = fetch_report date

      values.each do |indicator, value|
        ReportValue.create name: "#{date} - #{indicator}",
                           indicator_name: indicator,
                           contents: value,
                           content_type: 'integer',
                           report: report
      end
    end
  end

  def fetch_report(date)
    report = Report.find_by type: report_type('Visits'),
                            name: 'Daily visits',
                            start_date: date,
                            end_date: date
    report || create_report(date)
  end

  def create_report(date)
    Report.create type: fetch_report_type,
                  name: 'Daily visits',
                  start_date: date,
                  end_date: date,
                  renderer_type: 'Plain text'
  end

  def fetch_report_type
    type = report_type('Visits')
    type || ReportType.create(name: 'Visits', creator: User.current.id)
  end
end
