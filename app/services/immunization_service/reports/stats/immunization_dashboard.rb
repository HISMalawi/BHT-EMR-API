module ImmunizationService
    module Reports
        module Stats
            class ImmunizationDashboard
                def initialize(start_date:, end_date:)
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
                        total_men_vaccinated_today:
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

                end

                def total_children_vaccinated_today
                    cutoff_date = 18.years.ago.to_date

                    base_query.where(
                        encounter_type: { name: "IMMUNIZATION RECORD" }, 
                        concept_name: { name: "Batch Number"},
                        obs: { obs_datetime: @start_date..@end_date },
                        person: { birthdate: cutoff_date..Date.today}
                    ).select(:concept_id).count
                end

                def total_women_vaccinated_today
                    base_query.where(
                        encounter_type: { name: "IMMUNIZATION RECORD" }, 
                        concept_name: { name: "Batch Number"},
                        obs: { obs_datetime: @start_date..@end_date },
                        person: { gender: "F" }
                    ).select(:concept_id).count
                end

                def total_men_vaccinated_today
                    base_query.where(
                        encounter_type: { name: "IMMUNIZATION RECORD" }, 
                        concept_name: { name: "Batch Number"},
                        obs: { obs_datetime: @start_date..@end_date },
                        person: { gender: "M" }
                    ).select(:concept_id).count
                end

            end
        end
    end
end