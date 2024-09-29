class Stage < ApplicationRecord
    belongs_to :visit 
    belongs_to :patient 
  
    VALID_STAGES = %w[VITALS CONSULTATION DISPENSATION].freeze

    validates :stage, inclusion: { in: VALID_STAGES, message: "%{value} is not a valid stage" }
    
    validates :patient_id, :arrivalTime, :visit_id, :status, presence: true
end
  