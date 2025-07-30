class NtpRegimen < VoidableRecord
  self.table_name = 'ntp_regimens'
  self.primary_key = 'id'
  #Drug Name, Units, Concept name
  belongs_to :drug, foreign_key: :drug_id


  def as_json(options = {})
    super(options.merge(
      include: {
        drug: {}
      }
    ))
  end

  def self.adjust_weight_band(drugs, patient_weight)
    NtpRegimen.joins(:drug)
              .where('? BETWEEN min_weight AND max_weight', patient_weight)
              .where(drug_id: drugs.map(&:drug_id))
  end
 
end 
