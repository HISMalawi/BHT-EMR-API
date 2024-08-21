include TimeUtils

class TbService::DCToolsEngine
  LOGGER = Rails.logger

  SCENARIOS = {
    'REGISTERED PATIENTS' => TbService::DCTools::RegisteredPatients
  }.freeze

  def find_scenario (type:, name:, start_date:, end_date:)
    scenario = SCENARIOS[type.upcase]
    raise InvalidParameterError, "Scenario (#{type}) not known" unless scenario

    context = scenario.method(name.strip.split(' ').join('_').to_sym)
    raise InvalidParameterError, "Scenario context (#{name}) not known" unless context

    start_date = start_date.to_time
    _, end_date = TimeUtils.day_bounds(end_date)

    context.call(start_date, end_date)
  end
end