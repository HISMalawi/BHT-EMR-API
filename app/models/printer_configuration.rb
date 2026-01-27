class PrinterConfiguration
  include Mongoid::Document
  include Mongoid::Timestamps

  field :ip_address, type: String
  field :location_id, type: String
  field :printer_name, type: String

  index({ ip_address: 1 })
  index({ location_id: 1 })
  index({ printer_name: 1 })

  validates :ip_address, presence: true
  validates :location_id, presence: true
  validates :printer_name, presence: true
end