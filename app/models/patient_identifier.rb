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

# def self.next_available_arv_number
#   current_arv_code = self.site_prefix
#   type = PatientIdentifierType.find_by_name('ARV Number').id
#   current_arv_number_identifiers = PatientIdentifier.find(:all,:conditions => ["identifier_type = ? AND voided = 0",type])
#   assigned_arv_ids = current_arv_number_identifiers.collect{|identifier|
#     $1.to_i if identifier.identifier.match(/#{current_arv_code} *(\d+)/)
#   }.compact unless current_arv_number_identifiers.nil?
#   next_available_number = nil
#   if assigned_arv_ids.empty?
#     next_available_number = 1
#   else
#     # Check for unused ARV idsV
#     # Suggest the next arv_id based on unused ARV ids that are within 10 of the current_highest arv id. This makes sure that we don't get holes unless we   really want them and also means that our suggestions aren't broken by holes
#     #array_of_unused_arv_ids = (1..highest_arv_id).to_a - assigned_arv_ids
#     assigned_numbers = assigned_arv_ids.sort

#     possible_number_range = GlobalProperty.find_by_property("arv_number_range").property_value.to_i rescue 100000
#     possible_identifiers = Array.new(possible_number_range){|i|(i + 1)}
#     next_available_number = ((possible_identifiers)-(assigned_numbers)).first
#   end
#   return "#{current_arv_code} #{next_available_number}"
# end

# def self.identifier(patient_id, patient_identifier_type_id)
#   patient_identifier = self.find(:first, :select => "identifier",
#                                   :conditions  =>["patient_id = ? and identifier_type = ?", patient_id, patient_identifier_type_id])
#   return patient_identifier
# end

#   def self.out_of_range_arv_numbers(arv_number_range, start_date , end_date)
#     arv_number_id             = PatientIdentifierType.find_by_name('ARV Number').patient_identifier_type_id
#     national_identifier_id    = PatientIdentifierType.find_by_name('National id').patient_identifier_type_id
#     arv_start_number          = arv_number_range.first
#     arv_end_number            = arv_number_range.last

#     out_of_range_arv_numbers  = PatientIdentifier.find_by_sql(["SELECT patient_id, identifier, date_created FROM patient_identifier
#                                                                 WHERE identifier_type = ? AND  identifier >= ?
#                                                                 AND identifier <= ?
#                                                                 AND (NOT EXISTS(SELECT * FROM patient_identifier
#                                                                     WHERE identifier_type = ? AND date_created >= ? AND date_created <= ?))",
#                                                                       arv_number_id,  arv_start_number,  arv_end_number,
#                                                                       arv_number_id, start_date, end_date])
#     out_of_range_arv_numbers_data = []
#     out_of_range_arv_numbers.each do |arv_num_data|
#       patient     = Person.find(arv_num_data[:patient_id].to_i)
#       national_id = PatientIdentifier.identifier(arv_num_data[:patient_id], national_identifier_id).identifier rescue ""

#       out_of_range_arv_numbers_data <<[arv_num_data[:patient_id], arv_num_data[:identifier], patient.name,
#                 national_id,patient.gender,patient.age,patient.birthdate,arv_num_data[:date_created].strftime("%Y-%m-%d %H:%M:%S")]
#     end

#     out_of_range_arv_numbers_data
#   end

#   def self.next_filing_number(type = 'Filing Number')
#     available_numbers = self.find(:all,
#                                   :conditions => ['identifier_type = ?',
#                                   PatientIdentifierType.find_by_name(type).id]).map{ | i | i.identifier }

#     filing_number_prefix = GlobalProperty.find_by_property("filing.number.prefix").property_value rescue "FN101,FN102"
#     prefix = filing_number_prefix.split(",")[0][0..3] if type.match(/filing/i)
#     prefix = filing_number_prefix.split(",")[1][0..3] if type.match(/Archived/i)

#     len_of_identifier = (filing_number_prefix.split(",")[0][-1..-1] + "00000").to_i if type.match(/filing/i)
#     len_of_identifier = (filing_number_prefix.split(",")[1][-1..-1] + "00000").to_i if type.match(/Archived/i)
#     possible_identifiers_range = GlobalProperty.find_by_property("filing.number.range").property_value.to_i rescue 300000
#     possible_identifiers = Array.new(possible_identifiers_range){|i|prefix + (len_of_identifier + i +1).to_s}

#     ((possible_identifiers)-(available_numbers.compact.uniq)).first
#   end
end
