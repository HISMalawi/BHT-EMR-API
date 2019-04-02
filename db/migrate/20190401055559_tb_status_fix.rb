class TbStatusFix < ActiveRecord::Migration[5.2]
  def change
    observations = ActiveRecord::Base.connection.select_all <<EOF
      SELECT obs.encounter_id, obs.obs_datetime
      FROM obs INNER JOIN encounter e ON e.encounter_id = obs.encounter_id
      WHERE e.voided = 0 AND e.encounter_type = 53 
      AND e.encounter_datetime >= '2019-01-01 00:00:00'
      AND concept_id = 7459;
EOF

    encounter_ids = [0]

    (observations || []).each do |ob|
      encounter_ids << ob['encounter_id'].to_i
    end

    encounters = ActiveRecord::Base.connection.select_all <<EOF
      SELECT e.patient_id, e.encounter_id, e.encounter_datetime,
      e.date_created, e.creator
      FROM encounter e WHERE e.voided = 0 AND e.encounter_type = 53 
      AND e.encounter_datetime >= '2019-01-01 00:00:00'
      AND encounter_id NOT IN(#{encounter_ids.join(',')})
      GROUP BY e.encounter_id;
EOF

    (encounters || []).each_with_index do |e, i|
      ActiveRecord::Base.connection.execute <<EOF
      INSERT INTO obs (encounter_id, person_id, obs_datetime, concept_id,
      value_coded, uuid, creator, date_created) VALUES(#{e['encounter_id']}, #{e['patient_id']},
      '#{e['encounter_datetime'].to_time.strftime('%Y-%m-%d %H:%M:%S')}', 
      7459, 7454, uuid(), #{e['creator']},
      '#{e['date_created'].to_time.strftime('%Y-%m-%d %H:%M:%S')}');
EOF


      puts "#{(i + 1)} of ... #{encounters.length}"
    end

  end
end
