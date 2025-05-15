SELECT 
       pp.patient_id,
       (SELECT property_value FROM global_property WHERE property='current_health_center_id') AS site_id,
       pp.program_id,
       ppp.name program_name,
       ps.start_date, ps.end_date,
       cn.name patient_state
FROM   patient_state ps
   JOIN program_workflow_state pws
ON ps.state = pws.program_workflow_state_id and ps.voided=0 and ps.voided=0
   JOIN patient_program pp
ON ps.patient_program_id = pp.patient_program_id and pp.voided=0
   JOIN concept_name cn on  
   cn.concept_id = COALESCE(pws.concept_id,1067) and cn.locale = 'en' AND cn.voided = 0 AND cn.concept_name_type = 'FULLY_SPECIFIED' 
   JOIN concept_name cn2 on cn2.concept_id = COALESCE(pws.concept_id, 1067)
   and  cn2.locale = 'en' AND cn2.voided = 0 AND cn2.concept_name_type = 'FULLY_SPECIFIED'
   JOIN program ppp on  pp.program_id=ppp.program_id and pp.voided=0
WHERE pp.patient_id = @patient_id;
