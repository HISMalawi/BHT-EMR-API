class Visit < VoidableRecord 
  before_create :generate_uuid

  #private

  def generate_uuid
    self.uuid ||= SecureRandom.uuid
  end

  def self.find_by_uuid(uuid)        
    find_by(uuid: uuid)
  end   
  
  self.table_name = 'visit'
  self.primary_key = 'visit_id'
   
  belongs_to :patient, optional: false
   # belongs_to :patient, foreign_key: :patient_id, primary_key: :patient_id
  belongs_to :person, foreign_key: :patient_id, primary_key: :person_id
   # belongs_to :concept
   # belongs_to :program, foreign_key: :concept_id, primary_key: :program_id        
  belongs_to :visit_type, optional: false   
  belongs_to :indication, class_name: 'Concept', optional: true
  belongs_to :location
   
    
  has_many :encounters, -> { order(encounter_datetime: :desc, encounter_id: :desc) }
    
  validates :date_started, presence: true
  
  before_validation :validate_dates
  
    def as_json(options = {})
      super(options.merge(methods: %i[visit_type_name], include: %i[patient]))
    end
  
    def visit_type_name
      visit_type&.name
    end
  
    # check visit start and end date are valid
    # should contain time in their values and start date should be before end date
    def validate_dates
      # check if date_started has a valid date and time instead of zeros for time
      errors.add(:date_started, 'should contain time') if date_started && date_started.strftime('%H:%M:%S') == '00:00:00'
      
      # check if date_stoped has a valid date and time instead of zeros for time
      errors.add(:date_stopped, 'should contain time') if date_stopped && date_stopped.strftime('%H:%M:%S') == '00:00:00'
  
      return unless date_started && date_stopped && date_started > date_stopped
      
      erors.add(:date_started, 'should be before date stopped')
      
    end
    
    def voided_encounters
      encounters.where(voided: true)
    end
  
    def encounters_done
      encounters
    end
    
    def add_encounter(encounter)
      return unless encounter
      encounter.visit = self
      encounters << encounter
      
    end
  end
  