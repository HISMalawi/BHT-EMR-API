# frozen_string_literal: true

class NationalId < ApplicationRecord
  self.table_name = :national_id

  def self.next_id(patient_id = nil)
    id = where(assigned: 0).first
    return nil if id.nil?
    return id.national_id if patient_id.nil?

    id.assigned = true
    id.eds = true
    id.date_issued = Time.now
    id.creator = User.current_user.id
    id.save
    id.national_id
  end

  def self.next_ids_available_label(location_name = nil)
    id = active.find(:first, order: 'id DESC')
    return '' if id.blank?

    national_id = "#{id.national_id[0..2]}-#{id.national_id[3..]}"
    label = ZebraPrinter::StandardLabel.new
    label.draw_barcode(40, 210, 0, 1, 5, 10, 70, false, id.national_id.to_s)
    label.draw_text('Name:', 40, 30, 0, 2, 2, 2, false)
    label.draw_text("#{national_id}  dd__/mm__/____  (F/M)", 40, 110, 0, 2, 2, 2, false)
    label.draw_text('TA:', 40, 160, 0, 2, 2, 2, false)
    id.assigned = true
    id.date_issued = Time.now
    id.issued_to = location_name
    id.creator = User.current_user.id
    id.save
    label.print(1)
  end
end
