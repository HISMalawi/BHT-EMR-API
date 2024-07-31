module ImmunizationService
    module Reports
        module Stats
            class ImmunizationDashboard

            
                def initialize(start_date:, end_date:, location_id:)
                    @current_date = Date.current
                    @start_date = Date.parse(start_date).beginning_of_day
                    @end_date = Date.parse(end_date).end_of_day
                    @location_id = location_id
                end

                def data
                    {
                        total_client_registered:,
                        total_male_registered:,
                        total_female_registered:,
                        total_vaccinated_this_year:,
                        total_female_vaccinated_this_year:,
                        total_male_vaccinated_this_year:,
                        vaccination_counts_by_month:,
                    }
                end

                def base_query
                    Observation.joins(concept: :concept_names, 
                                encounter: %i[program type], person: [])
                               .where( program: { program_id: 33 },  
                                      location_id: @location_id)
                end

                def total_client_registered
                    base_query
                        .where(
                            encounter_type: { name: "REGISTRATION"},
                            obs: { obs_datetime: @start_date..@end_date }
                        )
                        .distinct
                        .count(:person_id)
                end

                def total_male_registered
                    base_query
                    .where(
                    encounter_type: { name: "REGISTRATION" },
                    obs: { obs_datetime: @start_date..@end_date },
                    person: { gender: "M" }
                    )
                    .distinct
                    .count(:person_id)
                end

                def total_female_registered
                    base_query
                    .where(
                    encounter_type: { name: "REGISTRATION" },
                    obs: { obs_datetime: @start_date..@end_date },
                    person: { gender: "F" }
                    )
                    .distinct
                    .count(:person_id)
                end

                def total_vaccinated_this_year
                    base_query
                      .where(
                        encounter_type: { name: "IMMUNIZATION RECORD" },
                        concept_name: { name: "Batch Number" },
                        obs: { obs_datetime: @start_date..@end_date }
                      )
                      .distinct
                      .count(:person_id)
                end
                         
                def total_female_vaccinated_this_year
                    base_query
                        .where(
                        encounter_type: { name: "IMMUNIZATION RECORD" },
                        concept_name: { name: "Batch Number" },
                        obs: { obs_datetime: @start_date..@end_date },
                        person: { gender: "F" }
                        ).distinct
                        .count(:person_id)
                end
                  
                def total_male_vaccinated_this_year
                    base_query
                        .where(
                        encounter_type: { name: "IMMUNIZATION RECORD" },
                        concept_name: { name: "Batch Number" },
                        obs: { obs_datetime: @start_date..@end_date },
                        person: { gender: "M" }
                        )
                        .distinct
                        .count(:person_id)
                end
                  
                def vaccination_counts_by_month
                    current_date = Date.today
                    months = []
                    vaccinations = []
                    
                    12.times do |i|
                        start_date = current_date.beginning_of_month - i.months
                        end_date = current_date.end_of_month - i.months
                    
                        month_name = start_date.strftime("%b") # Short month name
                        count = base_query
                                .where(
                                    encounter_type: { name: "IMMUNIZATION RECORD" },
                                    concept_name: { name: "Batch Number" },
                                    obs: { obs_datetime: start_date..end_date }
                                )
                                .distinct
                                .count(:person_id)
                    
                        months << month_name
                        vaccinations << count
                    end
                    
                    { months: months.reverse, vaccinations: vaccinations.reverse }
                end
            end
        end
    end
end