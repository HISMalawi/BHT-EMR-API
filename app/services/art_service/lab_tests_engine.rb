# frozen_string_literal: true

class ARTService::LabTestsEngine
  include ModelUtils

  def initialize(program:)
    @program = program
  end

  def type(type_id)
    LabTestType.find(type_id)
  end

  def types(search_string: nil, panel_id: nil)
    query = LabTestType
    query = query.where('TestName like ?', "%#{search_string}%") if search_string
    query = query.where(Panel_ID: panel_id) if panel_id
    query.order(:TestName)
  end

  def panels(search_string: nil)
    query = LabPanel.joins(:types)
    query = query.where('name like ?', "%#{search_string}%") if search_string
    query.order(:name).group(:rec_id)
  end

  def results(accession_number)
    LabParameter.joins(:lab_sample)\
                .where('Lab_Sample.AccessionNum = ?', accession_number)\
                .order(Arel.sql('DATE(Lab_Sample.TimeStamp) DESC'))
  end

  def create_order(type:, encounter:, patient: nil, date: nil)
    patient ||= encounter.patient
    date ||= encounter.encounter_datetime

    local_order = create_local_order patient, encounter, date
    local_order.accession_number = next_id local_order.order_id
    local_order.save!

    lab_order = create_lab_order type, local_order, date
    lab_sample = create_lab_sample lab_order

    create_result lab_sample: lab_sample, test_type: type

    { order: local_order, lab_test_table: lab_order.as_json }
  end

  def find_orders_by_patient(patient, paginate_func: nil)
    local_orders = local_orders(patient)
    local_orders = paginate_func.call(local_orders) if paginate_func
    local_orders.each_with_object([]) do |local_order, collected_orders|
      orders = find_orders_by_accession_number local_order.accession_number
      collected_orders.push(*orders)
    end
  end

  def find_orders_by_accession_number(accession_number)
    LabTestTable.where(Pat_ID: accession_number).order(Arel.sql('DATE(OrderDate), TIME(OrderTime)'))
  end

  def save_result(accession_number:, test_value:, time:)
    sample = LabSample.find_by(AccessionNum: accession_number)
    unless sample
      raise InvalidParameterError,
            "Couldn't find Lab parameter associated with accession number: #{accession_number}"
    end

    result = LabParameter.find_by(Sample_ID: sample.Sample_ID)
    unless result
      raise InvalidParameterError,
            "Couldn't find Lab parameter associated with accession number: #{accession_number}"
    end

    modifier, value = split_test_value(test_value)
    result.Range = modifier
    result.TESTVALUE = value
    result.TimeStamp = time || Time.now
    result.save
  end

  private

  # Creates an Order in the primary openmrs database
  def create_local_order(patient, encounter, date)
    Order.create patient: patient,
                 encounter: encounter,
                 concept: concept('Laboratory tests ordered'),
                 order_type: order_type('Lab'),
                 start_date: date,
                 provider: User.current
  end

  # Creates a lab order in the secondary healthdata database
  def create_lab_order(type, local_order, date)
    panel = LabPanel.find type.Panel_ID
    accession_number = next_id(local_order.order_id)
    LabTestTable.create TestOrdered: panel.name,
                        Pat_ID: accession_number,
                        OrderedBy: User.current.user_id,
                        OrderDate: date.respond_to?(:to_date) ? date.to_date : date,
                        OrderTime: Time.now.strftime('%2H:%2M'),
                        Location: Location.current.location_id
  end

  def create_lab_sample(lab_order)
    LabSample.create AccessionNum: lab_order.AccessionNum,
                     USERID: User.current.user_id,
                     TESTDATE: lab_order.OrderDate,
                     PATIENTID: lab_order.Pat_ID,
                     DATE: lab_order.OrderDate,
                     TIME: Time.now.strftime('%H:%M:%S'),
                     SOURCE: Location.current.location_id,
                     DeleteYN: 0,
                     Attribute: 'pass',
                     TimeStamp: Time.now
  end

  def create_result(lab_sample:, test_type:)
    LabParameter.create Sample_ID: lab_sample.Sample_ID,
                        TESTTYPE: test_type.TestType,
                        TESTVALUE: nil,
                        TimeStamp: Time.now,
                        Range: '='
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

  def local_orders(patient)
    Order.where patient: patient,
                order_type: order_type('Lab'),
                concept: concept('Laboratory tests ordered')
  end
end
