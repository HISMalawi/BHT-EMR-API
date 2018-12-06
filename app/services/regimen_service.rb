# frozen_string_literal: true

class RegimenService
  ENGINES = {
    'HIV PROGRAM' => ARTService::RegimenEngine
  }.freeze

  def initialize(program_id:)
    @engine = load_engine program_id
  end

  def find_regimens(patient_weight:, patient_age:, patient_gender:)
    @engine.find_regimens patient_weight: patient_weight,
                          patient_age: patient_age,
                          patient_gender: patient_gender
  end

  def find_dosages(patient, date)
    @engine.find_dosages patient, date
  end

  def find_starter_pack(regimen, weight)
    @engine.find_starter_pack(regimen, weight)
  end

  private

  def load_engine(program_id)
    program = Program.find program_id

    engine = ENGINES[program.concept.concept_names[0].name.upcase]
    engine.new program: program
  end
end
