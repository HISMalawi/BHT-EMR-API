class Visit < ApplicationRecord
    validates :patientId, presence: true
    validates :startDate, presence: true
    validates :programId, presence: true

    has_many :stages
    belongs_to :location, optional: true   
end   