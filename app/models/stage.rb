class Stage < ApplicationRecord
    belongs_to :visit
    belongs_to :patient
    belongs_to :location, optional: true  
                                                                       
    VALID_STAGES = %w[VITALS CONSULTATION LAB DISPENSATION].freeze
  
    # Validation to allow `true` and `false` for status
    validates :status, inclusion: { in: [true, false], message: "must be true or false" }   
  
    validates :patient_id, :arrivalTime, :visit_id, :stage, presence: true
    validates :stage, inclusion: { in: VALID_STAGES, message: "%{value} is not a valid stage" }
end
  