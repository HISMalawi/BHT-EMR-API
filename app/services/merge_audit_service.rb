# frozen_string_literal: true

# This service will handle merge audits with their tree structure
class MergeAuditService
  # This method a merge audit for us
  def create_merge_audit(primary_patient, secondary_patient, merge_type)
    recent_merge_id = MergeAudit.where(primary_id: secondary_patient).last&.id
    merge_audit = MergeAudit.create({ primary_id: primary_patient, secondary_id: secondary_patient,
                                      creator: User.current.id, merge_type: merge_type,
                                      secondary_previous_merge_id: recent_merge_id })
    raise "Could not create audit trail due to #{merge_audit.errors.as_json}" unless merge_audit.errors.empty?
  end

  # this uses the patient identifier to get the audit tree
  def get_patient_audit(identifier)
    fetch_merge_audit(find_voided_identifier(identifier))
  end

  # this uses the patient id to get the audit tree and it is used by get patient_audit
  def fetch_merge_audit(secondary)
    first_merge = common_merge_fetch('ma.secondary_id', secondary)
    raise NotFoundError, "There is no merge for #{secondary}" if first_merge.blank?

    tree = [first_merge]
    merge_id = MergeAudit.where(primary_id: first_merge['primary_id']).last&.id
    until merge_id.blank?
      parent = common_merge_fetch('ma.secondary_previous_merge_id', merge_id)
      tree << parent unless parent.blank?
      merge_id = parent.blank? ? nil : MergeAudit.where(primary_id: parent['primary_id']).last&.id
    end
    tree.reverse
  end

  def common_merge_fetch(field, fetch_value)
    ActiveRecord::Base.connection.select_one <<~SQL
      SELECT ma.id, ma.primary_id, ma.secondary_id, ma.created_at merge_date, ma.merge_type, pn.given_name primary_first_name, pn.family_name primary_surname, p.gender primary_gender, p.birthdate primary_birthdate,
      spn.given_name secondary_first_name, spn.family_name secondary_surname, sp.gender secondary_gender, sp.birthdate secondary_birthdate
      FROM merge_audits ma
      INNER JOIN person_name pn ON pn.person_id = ma.primary_id
      INNER JOIN person p ON p.person_id = ma.primary_id
      INNER JOIN person_name spn ON spn.person_id = ma.secondary_id AND spn.voided = 1
      INNER JOIN person sp ON sp.person_id = ma.secondary_id AND sp.voided = 1
      WHERE #{field} = #{fetch_value} AND ma.voided = 0
    SQL
  end

  def find_voided_identifier(identifier)
    result = ActiveRecord::Base.connection.select_one <<~SQL
      SELECT patient_id FROM patient_identifier WHERE identifier = '#{identifier}' AND voided = 1 ORDER BY date_voided ASC
    SQL
    raise NotFoundError, "Failed to find voided identifier: #{identifier}" if result.blank?

    result['patient_id']
  end
end
