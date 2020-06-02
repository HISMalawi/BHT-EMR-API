class Api::V1::CleaningController < ApplicationController

  SERVICES = {
    'ANC PROGRAM' => ANCService::DataCleaning,
    'HIV PROGRAM' => ARTService::DataCleaningTool
  }.freeze

  def index
    render json: ActiveRecord::Base.connection.select_all("SELECT DISTINCT concat(pn.given_name,' ',pn.family_name) AS name,p.identifier,tsd.death_date,e.encounter_datetime,tsd.gender,
    tsd.earliest_start_date,tsd.date_enrolled,tsd.birthdate,tsd.patient_id from temp_earliest_start_date tsd
    inner join patient_identifier p ON tsd.patient_id = p.patient_id
    inner join person_name pn ON pn.person_id = tsd.patient_id
    inner join encounter e ON e.patient_id = tsd.patient_id
    inner join person pp ON pp.person_id = tsd.patient_id
    where tsd.death_date<e.encounter_datetime AND pp.dead =1 AND p.identifier_type = 4
    group BY tsd.patient_id order by CONVERT(SUBSTRING_INDEX(p.identifier,'-',-1),UNSIGNED INTEGER)").each do
    |rows| puts rows ['dead']
     end
  end


  def dateEnrolled
   render json: ActiveRecord::Base.connection.select_all("SELECT DISTINCT concat(pn.given_name,' ',pn.family_name) AS name,p.identifier, tsd.gender,
   tsd.earliest_start_date,tsd.date_enrolled,tsd.birthdate,tsd.patient_id from temp_earliest_start_date tsd
   inner join patient_identifier p ON tsd.patient_id = p.patient_id
   inner join person_name pn ON pn.person_id = tsd.patient_id
   WHERE tsd.date_enrolled > tsd.earliest_start_date
   AND p.identifier_type = 4
   group BY tsd.patient_id order by CONVERT(SUBSTRING_INDEX(p.identifier,'-',-1),UNSIGNED INTEGER)").each do
   |rows| puts rows ['date']
    end
  end

  def incompleteVisits

    unless params[:program_id].blank?
      program = Program.find(params[:program_id])
      service = SERVICES[program.name.upcase].new(start_date: params[:start_date],
        end_date: params[:end_date], tool_name: params[:tool_name])
      render json: service.results
    else

    render json: ActiveRecord::Base.connection.select_all("    SELECT DISTINCT concat(pn.given_name,' ',pn.family_name) AS name,p.identifier, tsd.gender,
    tsd.earliest_start_date,tsd.date_enrolled,tsd.birthdate,tsd.patient_id from temp_earliest_start_date tsd
    inner join encounter enc on tsd.patient_id = enc.patient_id
    inner join patient_identifier p ON enc.patient_id = p.patient_id
    inner join person_name pn ON pn.person_id = enc.patient_id
    where enc.patient_id NOT IN (
    SELECT DISTINCT e.patient_id from encounter AS e
    where e.encounter_type = 6 AND 7 AND  9 AND 25 AND  51 AND 52 AND 53 AND 54
    ) AND enc.patient_id NOT IN(
    SELECT DISTINCT e.patient_id from encounter AS e
    where e.encounter_type = 6 AND 7 AND 25 AND 51 AND 54 AND 53 AND 68)
    AND p.identifier_type = 4

    UNION

    SELECT DISTINCT concat(pn.given_name,' ',pn.family_name) AS name,p.identifier, tsd.gender,
    tsd.earliest_start_date,tsd.date_enrolled,tsd.birthdate,tsd.patient_id from temp_earliest_start_date tsd
    inner join encounter AS e on tsd.patient_id = e.patient_id
    inner join patient_identifier p ON e.patient_id = p.patient_id
    inner join person_name pn ON pn.person_id = e.patient_id
    where e.patient_id NOT IN(
    SELECT DISTINCT e.patient_id from encounter AS e
    where e.encounter_type = 6 AND 7 AND 9 AND 25 AND 51 AND 52 AND 53 AND 54
    ) AND p.identifier_type = 4 order by CONVERT(SUBSTRING_INDEX(identifier,'-',-1),UNSIGNED INTEGER)").each do
    |rows| puts rows ['patient_id']
     end
    end
   end


  def dateEnrolledCounter
    render json: ActiveRecord::Base.connection.select_all('select COUNT(*)
     FROM (SELECT P.given_name,
     P.family_name, E.earliest_start_date,
    E.date_enrolled FROM earliest_start_date AS E JOIN person_name AS P
    ON P.person_id = E.patient_id
    WHERE E.date_enrolled < E.earliest_start_date
    group BY P.person_id order by CONVERT(SUBSTRING_INDEX(p.identifier,'-',-1),UNSIGNED INTEGER))').each do
    |rows| puts rows ['date']
     end
   end


  def startDate
      render json: ActiveRecord::Base.connection.select_all("SELECT DISTINCT concat(pn.given_name,' ',pn.family_name) AS name,p.identifier, tsd.gender,
      tsd.earliest_start_date,tsd.date_enrolled,tsd.birthdate,tsd.patient_id FROM temp_earliest_start_date tsd
      inner join patient_identifier p ON tsd.patient_id = p.patient_id
      INNER JOIN person_name AS pn ON pn.person_id = tsd.patient_id
      WHERE tsd.birthdate > tsd.earliest_start_date AND p.identifier_type = 4
      OR tsd.birthdate > tsd.date_enrolled AND p.identifier_type=4
      group BY tsd.patient_id order by CONVERT(SUBSTRING_INDEX(p.identifier,'-',-1),UNSIGNED INTEGER)").each do
      |rows| puts rows ['date']
      end
  end

   def male
       render json: ActiveRecord::Base.connection.select_all("SELECT DISTINCT concat(pn.given_name,' ',pn.family_name) AS name,p.identifier, tsd.gender,
       tsd.earliest_start_date,tsd.date_enrolled,tsd.birthdate,tsd.patient_id from  temp_earliest_start_date tsd
       inner join obs o ON tsd.patient_id = o.person_id
       inner join patient_identifier p ON tsd.patient_id = p.patient_id
       inner join person_name pn ON pn.person_id = tsd.patient_id
       inner join concept_name c ON c.concept_id = o.concept_id
       where c.name IN ('Is patient pregnant', 'Patient pregnant','Pregnant at initiation', 'Family planning', 'Breast feeding')
       AND tsd.gender='M' AND p.identifier_type = 4
       group BY tsd.patient_id order by CONVERT(SUBSTRING_INDEX(p.identifier,'-',-1),UNSIGNED INTEGER)").each do
      |rows| puts rows ['gender']
      end
  end

  def art_tools
    program = Program.find(params[:program_id])
    service = SERVICES[program.name.upcase].new(start_date: params[:start_date],
      end_date: params[:end_date], tool_name: params[:report_name])
    render json: service.results
  end

end
