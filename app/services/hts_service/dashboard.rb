# frozen_string_literal: true
# HTS Service
module HTSService
  # Dashbiard Class
  class Dashboard

  def self.daily_statistics(start_date,end_date)

       total = PatientProgram.where(program_id:18).count

art = Observation.joins("INNER JOIN concept_name ON concept_name.concept_id = obs.concept_id")
                 .joins("INNER JOIN encounter ON encounter.encounter_id = obs.encounter_id")
                 .where(obs: {value_text:"ART"},encounter:{program_id: 18},concept_name:{name:"Referrals ordered"})
                 .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(start_date))
                 .count

booked = Observation.joins("INNER JOIN concept_name ON concept_name.concept_id = obs.concept_id")
                    .joins("INNER JOIN encounter ON encounter.encounter_id = obs.encounter_id")
                    .where(encounter:{program_id: 18},concept_name:{name:"ART visit"})
                    .where('obs.value_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(start_date))
                    .count

tested = Observation.joins("INNER JOIN concept_name ON concept_name.concept_id = obs.concept_id")
                    .joins("INNER JOIN encounter ON encounter.encounter_id = obs.encounter_id")
                    .where(encounter:{program_id: 18},concept_name:{name:"ART visit"}, obs:{value_datetime:start_date})
                    .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(start_date))
                    .count

            stats = [{
                      hts_registered: total,
                      enrolled_on_art: art,
                      booked_appointments: booked,
                      tested_appointments: tested,
                     }]
   end



  end
end
