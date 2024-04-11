# frozen_string_literal: true

class ProgramPatientsService
  ENGINES = {
    'HIV PROGRAM' => ArtService::PatientsEngine,
    'TB PROGRAM' => TbService::PatientsEngine,
    'ANC PROGRAM' => AncService::PatientsEngine,
    'OPD PROGRAM' => OpdService::PatientsEngine,
    'VMMC PROGRAM' => VmmcService::PatientsEngine,
    'CXCA PROGRAM' => CxcaService::PatientsEngine,
    'HTC PROGRAM' => HtsService::PatientsEngine,
    'NCD PROGRAM' => NcdService::PatientsEngine,
  }.freeze

  def initialize(program:)
    clazz = ENGINES[program.name.upcase]
    raise NotFoundError, "Program patients engine for #{program} not registered" unless clazz

    @engine = clazz.new(program:)
  end

  def method_missing(method, *args, &block)
    Rails.logger.debug "Executing missing method: #{method}"
    return @engine.send(method, *args, &block) if respond_to_missing?(method)

    super(method, *args, &block)
  end

  def respond_to_missing?(method)
    Rails.logger.debug "Engine responds to #{method}? #{@engine.respond_to?(method)}"
    @engine.respond_to?(method)
  end

  def void_arv_number(arv_number)
    identifiers = PatientIdentifier.where(identifier: arv_number,
                                          identifier_type: PatientIdentifierType.find_by_name('ARV number').id)

    (identifiers || []).each do |identifier|
      identifier.update_columns(voided: 1, void_reason: 'Voided through the UI')
    end

    "Voided #{identifiers.count} ARV number(s)"
  end
end
