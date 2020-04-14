null_obs = Observation.unscoped.where(obs_datetime: nil)
total = null_obs.count

null_obs.each_with_index do |obs, i|
  puts "processing #{i} / #{total}" 
  encounter = Encounter.unscoped.find(obs['encounter_id'])

  obs.update(obs_datetime: encounter['encounter_datetime'],
  			 date_created: encounter['date_created'])
end