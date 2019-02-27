
require 'set'

module OPDService
  class ReportEngine
    include ModelUtils

    def initialize
    end

    # Retrieves the next encounter for bound patient
    def dashboard_stats(date)
      @date = date.to_date
      stats = {}
      stats[:top] = {
        registered_today: registered_today('New patient'), 
        returning_today: registered_today('Revisiting'),
        referred_today: registered_today('Referral') 
      }

      stats[:down] = {
        registered: monthly_registration('New patient'), 
        returning: monthly_registration('Revisiting'),
        referred: monthly_registration('Referral') 
      }

      return stats
    end

    private
    
    def registered_today(visit_type)
      type = EncounterType.find_by_name 'Patient registration'
      concept = ConceptName.find_by_name 'Type of visit'
      value_coded = ConceptName.find_by_name visit_type

      count = Encounter.where('encounter_datetime BETWEEN ? AND ?
        AND encounter_type = ? AND concept_id = ? 
        AND value_coded = ?', *TimeUtils.day_bounds(@date), type.id, 
        concept.concept_id, value_coded.concept_id).\
        joins('INNER JOIN obs USING(encounter_id)').\
        select('count(*) AS total')
      
      return count[0]['total'].to_i
    end

    def monthly_registration(visit_type)
      start_date = (@date - 12.month)
      dates = []
            
      start_date = start_date.beginning_of_month
      end_date  = start_date.end_of_month
      dates << [start_date, end_date]
    
      1.upto(11) do |m|
        sdate = start_date + m.month
        edate = sdate.end_of_month
        dates << [sdate, edate]
      end

      type = EncounterType.find_by_name 'Patient registration'
      concept = ConceptName.find_by_name 'Type of visit'
      value_coded = ConceptName.find_by_name visit_type

      months = {}
  
      (dates || []).each_with_index do |(date1, date2), i|
        count = Encounter.where('encounter_datetime BETWEEN ? AND ?
          AND encounter_type = ? AND concept_id = ? 
          AND value_coded = ?', date1.strftime('%Y-%m-%d 00:00:00'), 
          date2.strftime('%Y-%m-%d 23:59:59'), type.id, 
          concept.concept_id, value_coded.concept_id).\
          joins('INNER JOIN obs USING(encounter_id)').\
          select('count(*) AS total')
      
        months[(i+1)]= {
          start_date: date1, end_date: date2,
          count: count[0]['total'].to_i
        }
      end

      months
    end

  end
end
