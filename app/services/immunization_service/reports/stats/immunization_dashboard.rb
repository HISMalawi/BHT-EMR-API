module ImmunizationService
    module Reports
        module Stats
            class ImmunizationDashboard

            
                def initialize(start_date:, end_date:)
                    @current_date = Date.current
                    @start_date = Date.parse(start_date).beginning_of_day
                    @end_date = Date.parse(end_date).end_of_day
                end

                def data
                    {
                        total_client_registered:,
                        total_male_registered:,
                        total_female_registered:,
                        total_vaccinated:,
                        total_due_for_vaccination_today:,
                        total_missed_doses:,
                        total_vaccinated_today:,
                        total_children_vaccinated_today:,
                        total_women_vaccinated_today:,
                        total_men_vaccinated_today:,
                        vaccination_counts_by_month:,
                        client_overdue_under_five_years:,
                        client_overdue_over_five_years:
                    }
                end

                def base_query
                    Observation.joins(concept: :concept_names, 
                                encounter: %i[program type], person: [])
                               .where( program: { program_id: 33 })
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

                def total_vaccinated
                    base_query
                      .where(
                        encounter_type: { name: "IMMUNIZATION RECORD" },
                        concept_name: { name: "Batch Number" },
                        obs: { obs_datetime: @start_date..@end_date }
                      )
                      .distinct
                      .count(:person_id)
                end
                  

                def  total_due_for_vaccination_today
                    
                end

                def total_missed_doses

                end

                def total_vaccinated_today
                    base_query
                      .where(
                        encounter_type: { name: "IMMUNIZATION RECORD" },
                        concept_name: { name: "Batch Number" },
                        obs: { obs_datetime: @current_date.beginning_of_day..@current_date.end_of_day }
                      )
                      .distinct
                      .count(:person_id)
                  end
                  
                def total_children_vaccinated_today
                    base_query
                        .where(
                        encounter_type: { name: "IMMUNIZATION RECORD" },
                        concept_name: { name: "Batch Number" },
                        obs: { obs_datetime: @current_date.beginning_of_day..@current_date.end_of_day }
                        )
                        .where('TIMESTAMPDIFF(YEAR, person.birthdate, CURDATE()) < 18')
                        .distinct
                        .count(:person_id)
                end
                  
                def total_women_vaccinated_today
                    base_query
                        .where(
                        encounter_type: { name: "IMMUNIZATION RECORD" },
                        concept_name: { name: "Batch Number" },
                        obs: { obs_datetime: @current_date.beginning_of_day..@current_date.end_of_day },
                        person: { gender: "F" }
                        )
                        .where('TIMESTAMPDIFF(YEAR, person.birthdate, CURDATE()) >= 18')
                        .distinct
                        .count(:person_id)
                end
                  
                def total_men_vaccinated_today
                    base_query
                        .where(
                        encounter_type: { name: "IMMUNIZATION RECORD" },
                        concept_name: { name: "Batch Number" },
                        obs: { obs_datetime: @current_date.beginning_of_day..@current_date.end_of_day },
                        person: { gender: "M" }
                        )
                        .where('TIMESTAMPDIFF(YEAR, person.birthdate, CURDATE()) >= 18')
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

                def  client_overdue_under_five_years
                   followup_service.over_due_stats[:under_five]
                end
                
                def  client_overdue_over_five_years
                    followup_service.over_due_stats[:over_five]
                end

                def clients_due_today

                end 

                def clients_due_this_week

                end
                
                def clients_due_this_month
                    
                end

                private
                def followup_service
                    ImmunizationService::FollowUp.new()
                end
                  
            end
        end
    end
end