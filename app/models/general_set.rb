class GeneralSet < ApplicationRecord
    self.table_name = :dset
    self.primary_key = :set_id
  
    has_many :drug_sets, -> { where voided: 0 }, :foreign_key => :set_id#, optional: true
  
    def activate(date)
  
      if self.status != "active"
  
        self.update_attributes(:status => "active")
        self.update_attributes(:date_updated => date) if !date.blank?
      end
    end
  
    def deactivate(date)
  
      if self.status != "inactive"
        
        self.update_attributes(:status => "inactive")
        self.update_attributes(:date_updated => date) if !date.blank?
      end
    end
  
    def block(date)
  
      if self.status != "blocked"
  
        self.update_attributes(:status => "blocked")
        self.update_attributes(:date_updated => date) if !date.blank?
      end
    end
  
  end