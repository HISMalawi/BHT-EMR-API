class StagesService
  def create_stage(stage_params)
    identifier = stage_params[:identifier]
    patientId = stage_params[:patient_id]
    location_id = stage_params[:location_id] || User.current&.location_id

    if identifier.present?
      patient_identifier = PatientIdentifier.find_by(identifier: identifier)
      patientId = patient_identifier&.patient_id
    end

    existing_stage = Stage.find_by(
      patient_id: patientId,
      location_id: location_id
    )
    existing_stage&.destroy

    activeVisit = Visit.find_by(
      patientId: patientId,
      closedDateTime: nil
    )
    return nil if activeVisit.nil?

    created_stage = Stage.create(
      patient_id: patientId,
      visit_id: activeVisit.id,
      location_id: location_id,
      status: true,
      arrivalTime: stage_params[:arrivalTime],
      stage: stage_params[:stage]
    )

    stage_payload = {
      **stage_params.to_h.symbolize_keys,
      id: created_stage.id,
      patient_id: patientId,
      visit_id: activeVisit.id,
      location_id: location_id,
      identifier: resolve_identifier(identifier, patientId),
      status: true,
      fullName: Patient.find_by(patient_id: patientId)&.name,
    }

    broadcast_stage_update(
      "stage_created",
      stage_payload,
      extra_locations: [stage_params[:location_id], stage_params["location_id"], User.current&.location_id]
    )
    stage_payload
  end

  private

  def resolve_identifier(identifier, patient_id)
    return identifier if identifier.present?

    PatientIdentifier.unscoped
                     .where(patient_id: patient_id, identifier_type: 3, voided: 0)
                     .order(patient_identifier_id: :desc)
                     .limit(1)
                     .pluck(:identifier)
                     .first
  end

  def broadcast_stage_update(event_name, data, extra_locations: [])
    locations = [data[:location_id], data["location_id"], *Array(extra_locations)]
                .compact
                .map(&:to_s)
                .reject(&:blank?)
                .uniq
    return if locations.empty?

    payload = {
      event: event_name,
      data: data
    }

    locations.each do |location_id|
      ActionCable.server.broadcast("client_details_channel_#{location_id}", payload)
    end
  rescue StandardError => e
    Rails.logger.error("Failed to broadcast #{event_name}: #{e.message}")
  end
end
