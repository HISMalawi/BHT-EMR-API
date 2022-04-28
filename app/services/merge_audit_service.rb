# frozen_string_literal: true

# This service will handle merge audits with their tree structure
class MergeAuditService
  # This method a merge audit for us
  def create_merge_audit(primary_patient, secondary_patient)
    recent_merge_id = MergeAudit.where(primary_id: secondary_patient).last&.id
    merge_audit = MergeAudit.create({ primary_id: primary_patient, secondary_id: secondary_patient,
                                      creator: User.current.id, merge_type: merge_type,
                                      secondary_previous_merge_id: recent_merge_id })
    raise "Could not create audit trail due to #{merge_audit.errors.as_json}" unless merge_audit.errors.empty?
  end

  def fetch_merge_audit(secondary)
    first_merge = common_merge_fetch('ma.secondary_id', secondary)
    raise NotFoundError, "There is no merge for #{secondary}" if first_merge.blank?

    tree = [first_merge]
    merge_id = first_merge['id']
    until merge_id.blank?
      parent = common_merge_fetch('ma.secondary_previous_merge_id', merge_id)
      tree << parent unless parent.blank?
      merge_id = parent.blank? ? nil : parent['id']
    end
    tree
  end

  def common_merge_fetch(field, fetch_value)
    ActiveRecord::Base.connection.select_one <<~SQL
      SELECT ma.id, ma.primary_id, ma.secondary_id, pn.given_name primary_first_name, pn.family_name primary_surname, p.gender primary_gender, p.birthdate primary_birthdate,
      spn.given_name secondary_first_name, spn.family_name secondary_surname, sp.gender secondary_gender, sp.birthdate secondary_birthdate
      FROM merge_audits ma
      INNER JOIN person_name pn ON pn.person_id = ma.secondary_id
      INNER JOIN person p ON p.person_id = ma.secondary_id
      INNER JOIN person_name spn ON spn.person_id = ma.secondary_id AND spn.voided = 1
      INNER JOIN person sp ON sp.person_id = ma.secondary_id AND sp.voided = 1
      WHERE #{field} = #{fetch_value} AND ma.voided = 0
    SQL
  end
end
