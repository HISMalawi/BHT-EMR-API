# frozen_string_literal: true

require_relative '../nlims'

class TbService::LabTestsEngine
  include ModelUtils

  def initialize(program:)
    @program = program
  end

  def type(type_id)
    LabTestType.find(type_id) # health data schema
  end

  def types(search_string:)
    test_types = nlims.test_types

    return test_types unless search_string

    test_types.select { |test_type| test_type.start_with?(search_string) }
  end

  def lab_locations
    nlims.locations
  end

  def labs
    nlims.labs
  end

  def panels(test_type)
    nlims.specimen_types(test_type)
  end

  def results(accession_number)
    LabParameter.joins(:lab_sample)\
                .where('Lab_Sample.AccessionNum = ?', accession_number)\
                .order(Arel.sql('DATE(Lab_Sample.TimeStamp) DESC'))
  end # health data

  # Create test with lims
  def create_order(encounter:, date:, tests:, **kwargs)
    patient ||= encounter.patient
    date ||= encounter.encounter_datetime

    # test will take TB specific parameters

    tests.collect do |test|
      lims_order = nlims.order_tb_test(patient: patient,
                                       user: User.current,
                                       date: date,
                                       reason: test['reason'],
                                       test_type: [test['test_type']],
                                       sample_type: test['sample_type'],
                                       sample_status: test['sample_status'],
                                       target_lab: test['target_lab'],
                                       recommended_examination: test['recommended_examination'],
                                       treatment_history: test['treatment_history'],
                                       sample_date: test['sample_date'],
                                       sending_facility: test['sending_facility'],
                                       **kwargs)
      accession_number = lims_order['tracking_number']

      # creation happening here
      local_order = create_local_order(patient, encounter, date, accession_number)
      save_reason_for_test(encounter, local_order, test['reason'])

      { order: local_order, lims_order: lims_order }
    end
  end

  # find test with lims
  def find_orders_by_patient(patient, paginate_func: nil)
    local_orders = local_orders(patient)
    local_orders = paginate_func.call(local_orders) if paginate_func
    local_orders.each_with_object([]) do |local_order, collected_orders|
      next unless local_order.accession_number

      orders = find_orders_by_accession_number local_order.accession_number
      collected_orders.push(*orders)
    rescue LimsError => e
      Rails.logger.error("Error finding LIMS order: #{e}")
    end
  end

  # create test with lims
  def find_orders_by_accession_number(accession_number)
    order = nlims.patient_orders(accession_number)
    begin
      result = nlims.patient_results(accession_number)['results']
    rescue StandardError => e
      raise e unless e.message.include?('results not available')

      result = {}
    end

    [{
      sample_type: order['other']['sample_type'],
      date_ordered: order['other']['date_created'],
      order_location: order['other']['order_location'],
      specimen_status: order['other']['specimen_status'],
      accession_number: accession_number,
      tests: order['tests'].collect do |k, v|
        test_values = result[k]&.collect do |indicator, value|
          { indicator: indicator, value: value }
        end || []

        { test_type: k, test_status: v, test_values: test_values }
      end
    }]
  end



  def generate_lab_order_summary(order_info)

    identifier_type = PatientIdentifierType.find_by(name: 'National id').id
    identifier = PatientIdentifier.find_by(patient_id: order_info[:patient_id], identifier_type: identifier_type).identifier

    logger = Rails.logger
    logger.info "NATIONAL ID: #{identifier}"

    label = ZebraPrinter::StandardLabel.new
    label.draw_text('Lab Order Summary', 28, 9, 0, 1, 1, 2, false)
    label.draw_line(25, 35, 115, 1, 0)
    label.draw_line(180, 140, 600, 1, 0)

    label.draw_text('Order Date', 28, 56, 0, 2, 1, 1, false)
    label.draw_text('NPID', 28, 86, 0, 2, 1, 1, false)

    label.draw_text('Lab Tests', 28, 111, 0, 1, 1, 2, false)
    label.draw_text('Item', 190, 120, 0, 2, 1, 1, false)
    label.draw_text('Test Type', 28, 146, 0, 2, 1, 1, false)
    label.draw_text('Specimen', 28, 176, 0, 2, 1, 1, false)
    label.draw_text('Examination', 28, 206, 0, 2, 1, 1, false)
    label.draw_text('Target Lab', 28, 236, 0, 2, 1, 1, false)
    label.draw_text('Reason', 28, 266, 0, 2, 1, 1, false)
    label.draw_text('Previous TB', 28, 296, 0, 2, 1, 1, false)

    label.draw_line(260, 50, 170, 1, 0)
    label.draw_line(260, 50, 1, 60, 0)
    label.draw_line(180, 286, 600, 1, 0)
    label.draw_line(430, 50, 1, 60, 0) # NPID

    label.draw_line(180, 140, 1, 145, 0)
    label.draw_line(780, 140, 1, 145, 0) # Item end Close line

    # Order Data and NPID
    label.draw_line(260, 80, 170, 1, 0)
    label.draw_line(260, 110, 170, 1, 0)
    label.draw_line(260, 140, 170, 1, 0)

    label.draw_line(180, 170, 600, 1, 0)
    label.draw_line(180, 200, 600, 1, 0)
    label.draw_line(180, 230, 600, 1, 0)
    label.draw_line(180, 260, 600, 1, 0)

    label.draw_text(order_info[:date], 270, 56, 0, 2, 1, 1, false)
    label.draw_text(identifier, 270, 86, 0, 2, 1, 1, false)
    label.draw_text((order_info[:test_type]), 188, 146, 0, 2, 1, 1, false)
    label.draw_text(order_info[:specimen_type], 188, 176, 0, 2, 1, 1, false)
    label.draw_text(order_info[:recommended_examination], 188, 206, 0, 2, 1, 1, false)
    label.draw_text(order_info[:target_lab], 188, 236, 0, 2, 1, 1, false)
    label.draw_text(order_info[:reason_for_examination], 188, 266, 0, 2, 1, 1, false)
    label.draw_text(order_info[:previous_tb_patient], 188, 296, 0, 2, 1, 1, false)

    label.print(1)
  end

  private

  # Creates an Order in the primary openmrs database
  def create_local_order(patient, encounter, date, accession_number)
    Order.create patient: patient,
                 encounter: encounter,
                 concept: concept('Laboratory tests ordered'),
                 order_type: order_type('Lab'),
                 orderer: User.current.user_id,
                 start_date: date,
                 accession_number: accession_number,
                 provider: User.current
  end

  def save_reason_for_test(encounter, order, reason)
    Observation.create(
      order: order,
      encounter: encounter,
      concept: concept('Reason for test'),
      obs_datetime: encounter.encounter_datetime,
      person: encounter.patient.person,
      value_text: reason
    )
  end

  def next_id(seed_id)
    site_id = global_property('moh_site_id').property_value
    local_id = Order.where(order_type: order_type('Lab')).count + 1
    format '%<site_id>s%<seed_id>s%<local_id>d', site_id: site_id,
                                                 seed_id: seed_id,
                                                 local_id: local_id
  end

  TESTVALUE_SPLIT_REGEX = /^\s*(?<mod>[=<>])?\s*(?<value>\d+(.\d*)?\s*\w*|Positive|Negative)\s*$/i.freeze

  # Splits a test_value into its parts [modifier, value]
  def split_test_value(test_value)
    match = test_value.match TESTVALUE_SPLIT_REGEX
    raise InvalidParameterError, "Invalid test value: #{test_value}" unless match

    [match[:mod] || '=', translate_test_value(match[:value])]
  end

  def translate_test_value(value)
    case value.upcase
    when 'POSITIVE'
      '1.0'
    when 'NEGATIVE'
      '-1.0'
    else
      value
    end
  end

  # Local Order
  def local_orders(patient)
    Order.where patient: patient,
                order_type: order_type('Lab'),
                concept: concept('Laboratory tests ordered')
  end

  # Dont't forget to put this back in order
  def nlims
    @nlims ||= Nlims.instance
  end
end
