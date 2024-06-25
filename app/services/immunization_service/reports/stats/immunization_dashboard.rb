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
                        total_vaccinated:,
                        total_due_for_vaccination_today:,
                        total_missed_doses:,
                        total_vaccinated_today:,
                        total_children_vaccinated_today:,
                        total_women_vaccinated_today:,
                        total_men_vaccinated_today:,
                        vaccination_counts_by_month:
                    }
                end

                def base_query
                    Observation.joins(concept: :concept_names, 
                                encounter: %i[program type], person: [])
                               .where( program: { program_id: 33 })
                end

                def total_vaccinated
                    base_query.where(
                        encounter_type: { name: "IMMUNIZATION RECORD" }, 
                        concept_name: { name: "Batch Number"},
                        obs: { obs_datetime: @start_date..@end_date }
                    ).select(:concept_id).count
                end

                def  total_due_for_vaccination_today
                    
                end

                def total_missed_doses

                end

                def total_vaccinated_today 
                    base_query.where(
                      encounter_type: { name: "IMMUNIZATION RECORD" }, 
                      concept_name: { name: "Batch Number" },
                      obs: { obs_datetime: @current_date.beginning_of_day..@current_date.end_of_day }
                    ).select(:concept_id).count
                end
                  

                def total_children_vaccinated_today
                    base_query.where(
                      encounter_type: { name: "IMMUNIZATION RECORD" },
                      concept_name: { name: "Batch Number" },
                      obs: { obs_datetime: @current_date.beginning_of_day..@current_date.end_of_day }
                    ).where('TIMESTAMPDIFF(YEAR, person.birthdate, CURDATE()) < 18').select(:concept_id).count
                end
                  
                def total_women_vaccinated_today
                    base_query.where(
                      encounter_type: { name: "IMMUNIZATION RECORD" },
                      concept_name: { name: "Batch Number" },
                      obs: { obs_datetime: @current_date.beginning_of_day..@current_date.end_of_day },
                      person: { gender: "F" }
                    ).where('TIMESTAMPDIFF(YEAR, person.birthdate, CURDATE()) >= 18').select(:concept_id).count
                end
                  
                def total_men_vaccinated_today
                    base_query.where(
                      encounter_type: { name: "IMMUNIZATION RECORD" },
                      concept_name: { name: "Batch Number" },
                      obs: { obs_datetime: @current_date.beginning_of_day..@current_date.end_of_day },
                      person: { gender: "M" }
                    ).where('TIMESTAMPDIFF(YEAR, person.birthdate, CURDATE()) >= 18').select(:concept_id).count
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
                                .select(:concept_id)
                                .count
                
                      months << month_name
                      vaccinations << count
                    end
                
                    { months: months.reverse, vaccinations: vaccinations.reverse }
                end


        
            end
        end
    end
end