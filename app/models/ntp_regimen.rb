class NtpRegimen < VoidableRecord
  self.table_name = 'ntp_regimens'
  self.primary_key = 'regimen_id'
  #Drug Name, Units, Concept name
  belongs_to :drug, foreign_key: :drug_inventory_id


  def as_json(options = {})
    super(options.merge(
      include: {
        drug: {}
      }
    ))
  end
 
end
