class FixViralLoadTestTypes < ActiveRecord::Migration[5.2]
  def up
    ActiveRecord::Base.logger = Logger.new($stdout)

    viral_load = ConceptName.find_by(name: 'Viral load')
    retired_viral_loads = ConceptName.unscoped.where(name: ['HIV_viral_load', 'Viral laod'])

    Lab::LabTest.where(value_coded: retired_viral_loads.select(:concept_id)).each do |test|
      puts "Updating test ##{test.obs_id} value_coded to Viral load"
      test.update(value_coded: viral_load.concept_id)
    end

    retired_viral_loads.each do |concept_name|
      puts "Voiding concept #{concept_name.name}"
      concept_name.concept&.void("Duplicate of concept ##{viral_load.concept_id}")
      concept_name.void("Duplicate of concept ##{viral_load.concept_name_id}")
      ConceptSet.where(concept_set: concept_name.concept_id).each(&:delete)
      ConceptSet.where(concept_id: concept_name.concept_id).each(&:delete)
    end
  end

  def down; end
end
