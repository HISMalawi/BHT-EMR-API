class PatientService
  def find_by_identifier(identifier, identifier_type: nil)
    identifier_type ||= IdentifierType.find_by('National id')

    patient = Patient.joins(:patient_identifiers).where(
      'patient_identifier.identifier_type = ? AND patient_identifier.identifier = ?',
      identifier_type.patient_identifier_type_id, identifier
    ).first
  end
end
