# frozen_string_literal: true

require_relative '../nlims'

class TBService::LabTestsEngine
  include ModelUtils

  def initialize(program:)
    @program = program
  end

  def type(type_id)
    LabTestType.find(type_id) #health data schema
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
  end #health data

  #Create test with lims
  def create_order(encounter:, date:, tests:, **kwargs)
    patient ||= encounter.patient
    date ||= encounter.encounter_datetime

    #test will take TB specific parameters

    tests.collect do |test|
      lims_order = nlims.order_tb_test(patient: patient, 
                                      user: User.current, 
                                      date: date, 
                                      reason: test['reason'], 
                                      test_type: [test['test_type']], #observation
                                      sample_type: test['sample_type'], #observation
                                      sample_status: test['sample_status'], #observation
                                      target_lab: test['target_lab'], #observation
                                      recommended_examination: test['recommended_examination'], #observation
                                      treatment_history: test['treatment_history'], #observation
                                      sample_date: test['sample_date'],
                                      sending_facility: test['sending_facility'], #observation
                                      time_line: test['time_line'], #observation
                                      **kwargs)
      accession_number = lims_order['tracking_number']

      #creation happening here
      local_order = create_local_order(patient, encounter, date, accession_number)

      #encounter observations shouldn't be save here
      #save_reason_for_test(encounter, local_order, test['reason'])

      #add other observations here

      { order: local_order, lims_order: lims_order }
    end
  end

  #Add all observations
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

  #find test with lims
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
  
  #create test with lims
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

  #Local Order
  def local_orders(patient)
    Order.where patient: patient,
                order_type: order_type('Lab'),
                concept: concept('Laboratory tests ordered')
  end

  #Dont't forget to put this back in order
  def nlims
    return @nlims if @nlims

    config = YAML.load_file "#{Rails.root}/config/application.yml"
    @nlims = ::NLims.new config
    @nlims.auth config['lims_default_user'], config['lims_default_password']
    
    #@nlims.auth config['lims_username'], config['lims_password']
    @nlims
  end
end
