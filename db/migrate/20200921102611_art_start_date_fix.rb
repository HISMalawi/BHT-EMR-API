# frozen_string_literal: true

class ArtStartDateFix < ActiveRecord::Migration[5.2]
  def up
    concept_id = ConceptName.find_by(name: 'ART start date').concept_id
    obs = Observation.where('concept_id  = ? AND value_datetime IS NULL AND value_text IS NOT NULL', concept_id)

    (obs || []).each do |ob|
      art_start_date = ob.value_text.to_date
      ob.update_columns(value_datetime: art_start_date, value_text: nil)
      next
    rescue StandardError
      value_text = ob.value_text
      case value_text
      when /6/i
        art_start_date  = (ob.obs_datetime.to_date - 6.month).to_date
      when /18/i
        art_start_date  = (ob.obs_datetime.to_date - 18.month).to_date
      when /12/i
        art_start_date  = (ob.obs_datetime.to_date - 12.month).to_date
      when /24/i
        art_start_date  = (ob.obs_datetime.to_date - 24.month).to_date
      when /Over 2/i
        art_start_date  = (ob.obs_datetime.to_date - 24.month).to_date
      when /Unknown/i
        art_start_date  = (ob.obs_datetime.to_date - 12.month).to_date
      else
        next
      end

      ob.update_columns(value_datetime: art_start_date, value_text: "Estimated: #{value_text}")
    end
  end

  def down
    # Do nothing...
  end
end
