class Stage < ApplicationRecord
    validates :patientId, :stage, :arrivalTime, :visit_id, :status, presence: true

    belongs_to :visit 
end
