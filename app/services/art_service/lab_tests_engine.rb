# frozen_string_literal: true

class ARTService::LabTestsEngine
  include ModelUtils

  def initialize(program:)
    @program = program
  end

  def types(search_string: nil)
    query = if search_string
              LabTestType.where('TestName like ?', "%#{search_string}%")
            else
              LabTestType
            end

    query.order('TestName')
  end

  def create_order(type:, encounter:, patient: nil, date: nil)
    patient ||= encounter.patient
    date ||= encounter.encounter_datetime

    local_order = create_local_order patient, encounter, date
    local_order.accession_number = next_id local_order.order_id
    local_order.save!

    lab_order = create_lab_order type, local_order, date
    create_lab_sample lab_order

    { order: local_order, lab_test_table: lab_order.as_json }
  end

  def find_orders_by_patient(patient, paginate_func: nil)
    local_orders = Order.where patient: patient
    local_orders = paginate_func.call(local_orders) if paginate_func
    local_orders.each_with_object([]) do |local_order, collected_orders|
      orders = find_orders_by_accession_number local_order.accession_number
      collected_orders.push(*orders)
    end
  end

  def find_orders_by_accession_number(accession_number)
    LabTestTable.where(Pat_ID: accession_number).order('DATE(OrderDate), TIME(OrderTime)')
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

  def next_id(seed_id)
    site_id = global_property('moh_site_id').property_value
    local_id = Order.where(order_type: order_type('Lab')).count + 1
    format '%<site_id>s%<seed_id>s%<local_id>d', site_id: site_id,
                                                 seed_id: seed_id,
                                                 local_id: local_id
  end
end
