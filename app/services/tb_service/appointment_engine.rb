# frozen_string_literal: true

require 'logger'

module TBService
class AppointmentEngine
  include ModelUtils

  LOGGER = Logger.new STDOUT

  def initialize(program:, patient:, retro_date: Date.today)
    @retro_date = retro_date.respond_to?(:to_date) ? retro_date.to_date : date
    @program = program
    @patient = patient
  end

  def appointment(id)
    Observation.find_by obs_id: id, concept: concept('Appointment date')
  end

  def appointments(filters = {})
    date = filters.delete(:date) || filters.delete(:value_datetime)

    filters = filters.to_hash.each_with_object({}) do |kv_pair, transformed_hash|
      key, value = kv_pair
      transformed_hash["obs.#{key}"] = value
    end

    appointments = Observation.joins(:concept)\
                              .where(concept: concept('Appointment date'))
    if date
      appointments = appointments.where('value_datetime BETWEEN ? AND ?',
                                        *TimeUtils.day_bounds(date))
    end

    appointments = appointments.where(filters) unless appointments.empty?
    appointments.order(obs_datetime: :desc)
  end

  def next_appointment_date
    _drug_id, date = earliest_appointment_date(@patient, @retro_date)
    return nil unless date

    {
      drugs_run_out_date: date,
      appointment_date: revised_suggested_date(@patient, date)
    }
  end

  def make_appointment_date(patient, date)
    Observation.new concept: concept('Appointment date'),
                    value_datetime: date,
                    person: patient.person,
                    obs_datetime: Time.now
  end

  def appointment_encounter(patient, visit_date)
    encounter = Encounter.find_by patient_id: patient.patient_id,
                                  encounter_datetime: visit_date

    return encounter if encounter

    Encounter.new type: encounter_type('APPOINTMENT'),
                  patient: patient,
                  encounter_datetime: Time.now,
                  program: @program,
                  location_id: Location.current.location_id,
                  provider: User.current.person
  end

  def earliest_appointment_date(patient, date)
    orders = patient_tb_prescriptions patient, date
    return [] if orders.empty?

    amount_dispensed = {}

    orders.each do |order|
      next unless order.drug_order

      original_auto_expire_date = order.void_reason&.to_date

      if order.start_date.to_date == order.auto_expire_date.to_date\
        && original_auto_expire_date
        auto_expire_date = original_auto_expire_date
      else
        auto_expire_date = (order.discontinued_date || order.auto_expire_date).to_date
      end

      amount_dispensed[order.drug_order.drug_inventory_id] = auto_expire_date
    end

    amount_dispensed.min_by { |_drug_id, auto_expire_date| auto_expire_date }
  end

  # Retrieves all prescriptions of ARVs to patient on date
  def patient_tb_prescriptions(patient, date)
    encounter_type_id = encounter_type('TREATMENT').encounter_type_id
    tb_drug_concepts = Drug.tb_drugs.map(&:concept_id)

    Order.joins(
      'INNER JOIN drug_order ON drug_order.order_id = orders.order_id
       INNER JOIN encounter ON encounter.encounter_id = orders.encounter_id
       INNER JOIN drug ON drug.drug_id = drug_order.drug_inventory_id'
    ).where(
      'encounter.encounter_type = ? AND encounter.patient_id = ?
       AND (encounter.encounter_datetime BETWEEN ? AND ?)
       AND drug.concept_id IN (?)',
      encounter_type_id, patient.patient_id,
      date.to_date.strftime("%Y-%m-%d 00:00:00"),date.to_date.strftime("%Y-%m-%d 23:59:59"),
      tb_drug_concepts).order('encounter.encounter_datetime')
  end

  def revised_suggested_date(patient, expiry_date)
    clinic_appointment_limit = global_property('clinic.appointment.limit')&.property_value&.to_i
    clinic_appointment_limit = 200 if clinic_appointment_limit.nil? || clinic_appointment_limit < 1

    peads_clinic_days = global_property('peads.clinic.days')&.property_value
    if patient.age(today: @retro_date) <= 14 && !peads_clinic_days.blank?
      clinic_days = peads_clinic_days
    else
      clinic_days = global_property('clinic.days')&.property_value
      clinic_days ||= 'Monday,Tuesday,Wednesday,Thursday,Friday'
    end
    clinic_days = clinic_days.split(',').collect(&:strip)

    clinic_holidays = global_property('clinic.holidays')&.property_value
    clinic_holidays = begin
                        clinic_holidays.split(',').map { |day| day.to_date.strftime('%d %B') }.join(',').split(',')
                      rescue StandardError
                        []
                      end

    recommended_date = expiry_date.to_date

    expiry_date -= 2.days

    start_date = (expiry_date - 5.days).strftime('%Y-%m-%d 00:00:00')
    end_date = expiry_date.strftime('%Y-%m-%d 23:59:59')

    encounter_type = EncounterType.find_by_name('APPOINTMENT')
    concept_id = ConceptName.find_by_name('APPOINTMENT DATE').concept_id

    appointments = {}
    sdate = (end_date.to_date + 1.day)

    1.upto(10).each do |num|
      appointments[(sdate - num.day)] = 0
    end

    Observation.find_by_sql("SELECT value_datetime appointment_date, count(value_datetime) AS count FROM obs
      INNER JOIN encounter e USING(encounter_id) WHERE concept_id = #{concept_id}
      AND encounter_type = #{encounter_type.id} AND value_datetime BETWEEN '#{start_date}'
      AND '#{end_date}' AND obs.voided = 0 GROUP BY DATE(value_datetime), value_datetime").each do |appointment|
      appointments[appointment.appointment_date.to_date] = appointment.count.to_i
    end

    (appointments || {}).sort_by { |x, _y| x.to_date }.reverse_each do |date, count|
      next unless clinic_days.include?(date.to_date.strftime('%A'))
      next unless clinic_holidays.include?(date.to_date.strftime('%d %B')).blank?

      return date if count < clinic_appointment_limit
    end

    #     the following block of code will only run if the recommended date is full
    #     Its a hack, we need to find a better way of cleaning up the code but it works :)
    (appointments || {}).sort_by { |_x, y| y.to_i }.each do |date, _count|
      next unless clinic_days.include?(date.to_date.strftime('%A'))
      next unless clinic_holidays.include?(date.to_date.strftime('%d %B')).blank?

      recommended_date = date
      break
    end

    recommended_date
  end

  def calculate_complete_pack(drug, units)
    return units if drug.barcodes.blank? || units.to_f == 0.0

    drug.barcodes.sort_by(&:tabs).each do |barcode|
      return barcode.tabs if barcode.tabs >= units.to_f
    end

    smallest_available_tab = drug.barcodes.min_by(&:tabs).tabs
    complete_pack = drug.barcodes.max_by(&:tabs).tabs

    complete_pack += smallest_available_tab while complete_pack < units.to_f

    complete_pack
  end
end
end