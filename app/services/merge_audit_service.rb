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
    result = ActiveRecord::Base.connection.select_one <<~SQL
      SELECT *
      FROM merge_audits ma
      INNER JOIN person_name pn ON pn.person_id = ma.secondary_id AND pn.voided = 1
      INNER JOIN person p ON p.person_id = ma.secondary_id AND p.voided = 1
      WHERE ma.voided = 0 AND ma.secondary_id = #{secondary}
    SQL
  end
end
