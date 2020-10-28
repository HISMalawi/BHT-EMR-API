class PatientProgram < VoidableRecord
  self.table_name = 'patient_program'
  self.primary_key = 'patient_program_id'

  after_void :after_void

  belongs_to :patient
  belongs_to :program
  belongs_to :location
  has_many :patient_states, class_name: 'PatientState', dependent: :destroy

  def as_json(options = {})
    super(options.merge(
      include: {
        patient_states: {
          methods: :name
        },
        program: {
          include: {
            concept: {
              include: {
                concept_names: {}
              }
            }
          }
        }
      }
    ))
  end

  # named_scope :current, conditions: [
  #   'date_enrolled < NOW() AND (date_completed IS NULL OR date_completed > NOW())'
  # ]
  # named_scope :local, lambda do
  #   {
  #     conditions: [
  #       'location_id IN (?)',
  #       Location.current_health_center.children.map{ |l| l.id } + [Location.current_health_center.id]
  #     ]
  #   }
  # end

  validates_presence_of :date_enrolled, :program_id

  def after_void(reason)
    patient_states.each { |row| row.void(reason) }
  end

  # Returns patient's current state in program.
  #
  # NOTE: Unlike OpenMRS in it's purest form, a program is limited
  #       to one workflow, so at any point a patient must have only
  #       one state.
  def current_state(date)
    patient_states.where('start_date <= DATE(:date)
                          AND (end_date >= DATE(:date) OR end_date IS NULL)',
                         date: date)
                  .order(:start_date)
                  .last
  end
end
