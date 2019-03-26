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

  # def validate
  #   PatientProgram.find_all_by_patient_id(self.patient_id).each{|patient_program|
  #     next if self.program == patient_program.program
  #     if self.program == patient_program.program and self.location and self.location.related_to_location?(patient_program.location) and patient_program.date_enrolled <= self.date_enrolled and (patient_program.date_completed.nil? or self.date_enrolled <= patient_program.date_completed)
  #       errors.add_to_base "Patient already enrolled in program #{self.program.name rescue nil} at #{self.date_enrolled.to_date} at #{self.location.parent.name rescue self.location.name}"
  #     end
  #   }
  # end

  # def transition(params)
  #   ActiveRecord::Base.transaction do
  #     # Find the state by name
  #     # Used upcase below as we were having problems matching the concept fullname with the state
  #     # I hope this will sort the problem and doesnt break anything
  #     selected_state = self.program.program_workflows.map(&:program_workflow_states).flatten.select{|pws| pws.concept.fullname.upcase() == params[:state].upcase()}.first rescue nil
  #     state = self.patient_states.last rescue []
  #     if (state && selected_state == state.program_workflow_state)
  #       # do nothing as we are already there
  #     else
  #       # Check if there is an open state and close it
  #       if (state && state.end_date.blank?)
  #         state.end_date = params[:start_date]
  #         state.save!
  #       end
  #       # Create the new state
  #       state = self.patient_states.new({
  #         :state => selected_state.program_workflow_state_id,
  #         :start_date => params[:start_date] || Date.today,
  #         :end_date => params[:end_date]
  #       })
  #       state.save!
  #     end
  #   end
  # end

  # # This is a pretty clumsy way of finding which regimen the patient is on.
  # # Eventually it would be good to have a way to associate a program with a
  # # regimen type without doing it manually. Note, the location of the regimen
  # # obs must be the current health center, not the station!
  # def current_regimen
  #   location_id = Location.current_health_center.location_id
  #   obs = patient.person.observations.recent(1).all(:conditions => ['value_coded IN (?) AND location_id = ?', regimens, location_id])
  #   obs.first.value_coded rescue nil
  # end

  # # Actually returns +Concept+s of suitable +Regimen+s for the given +weight+
  # def regimens(weight=nil)
  #   self.program.regimens(weight)
  # end

  # def closed?
  #   (self.date_completed.blank? == false)
  # end

end
