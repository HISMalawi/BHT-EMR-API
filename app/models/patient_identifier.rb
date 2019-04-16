class PatientIdentifier < VoidableRecord
  self.table_name = :patient_identifier
  self.primary_key = :patient_identifier_id

  belongs_to(:type, class_name: 'PatientIdentifierType',
                    foreign_key: :identifier_type)
  belongs_to(:patient, class_name: 'Patient', foreign_key: :patient_id)

  def as_json(options = {})
    super(options.merge(methods: %i[type]))
  end

  def self.calculate_checkdigit(number)
    # This is Luhn's algorithm for checksums
    # http://en.wikipedia.org/wiki/Luhn_algorithm
    # Same algorithm used by PIH (except they allow characters)
    number = number.to_s
    number = number.split(//).collect(&:to_i)
    parity = number.length % 2

    sum = 0
    number.each_with_index do |digit, index|
      digit *= 2 if index % 2 == parity
      digit -= 9 if digit > 9
      sum += digit
    end

    checkdigit = 0
    checkdigit += 1 while ((sum + checkdigit) % 10) != 0
    checkdigit
  end

  def self.site_prefix
    GlobalProperty.find_by_property('site_prefix').property_value
  rescue StandardError => e
    Rails.logger.error "Suppressed exception: #{e}"
    nil
  end
end
