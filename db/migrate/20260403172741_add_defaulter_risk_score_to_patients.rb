class AddDefaulterRiskScoreToPatients < ActiveRecord::Migration[7.0]
  def change
    add_column :patient, :defaulter_risk_score, :float
    add_column :patient, :risk_assessed_at, :datetime
  end
end
