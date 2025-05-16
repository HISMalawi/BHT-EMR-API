module ArtService
  class Dashboard
    attr_accessor :date, :program, :report

    include TimeUtils
    
    def initialize(date:)
      @date = date
      @program = Program.find_by_name('HIV PROGRAM')
      @report = OpenStruct.new(struct)
    end

    def struct
      {
        total_patients_today: [],
        waiting_for_vitals: [],
        waiting_for_consultation: [],
        waiting_for_dispensation: [],
        encounters_created_today: [],
        total_visits: {
          complete: [],
          incomplete: []
        }
      }
    end

    def dashboard
      report.total_patients_today = total_patients_today.map(&:patient_id)
      report.total_patients_today.each do |patient_id|
        report.waiting_for_vitals << patient_id if workflow(patient_id:).next_encounter&.name == 'VITALS'
        report.waiting_for_consultation << patient_id if workflow(patient_id:).next_encounter&.name == 'HIV CLINIC CONSULTATION'
        report.waiting_for_dispensation << patient_id if workflow(patient_id:).next_encounter&.name == 'DISPENSING'

        key = workflow(patient_id:).next_encounter.blank? ? :complete : :incomplete

        report.total_visits[key] << patient_id
      end
      report.encounters_created_today = encounters_created_today
      
      report.table
    end

    def encounters_created_today
      Encounter.where(program:)
        .where('encounter_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(date))
        .select(:encounter_type, 'CONCAT(patient_id) AS count')
        .group(:encounter_type)&.map do |e| 
          {
            name: e.type.name,
            count: e.count.split(',')
          }
        end || []
    end

    def total_patients_today
      Encounter.where(program:)
        .where('encounter_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(date))
        .select(:patient_id)
        .group(:patient_id) || []
    end

    def workflow(patient_id:)
      ArtService::WorkflowEngine.new(
        patient: Patient.find(patient_id),
        date:,
        program:,
        activities: 'all'
      )
    end
  end
end