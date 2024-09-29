class Stage < ApplicationRecord
    validates :patient_id, :stage, :arrivalTime, :visit_id, :status, presence: true

    belongs_to :visit 
    belongs_to :patient 
end
