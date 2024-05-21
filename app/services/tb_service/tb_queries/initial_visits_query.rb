include ModelUtils

class TbService::TbQueries::InitialVisitsQuery
  def initialize (start_date, end_date)
    @start_date = start_date
    @end_date = end_date
  end

  def referred_from_sscp
    sscp_referrals = source_of_referral('Community sputum collection site')
    presumptives.where(patient_id: sscp_referrals).distinct
  end

  def referred_from_hh_tb_screening_sites
    hh_referrals = source_of_referral('HH TB screening sites')
    presumptives.where(patient_id: hh_referrals).distinct
  end

  def cases_among_sputum_collection_points
    scp_referrals = source_of_referral('Sputum collection point')
    enrolled.where(patient_id: scp_referrals).distinct
  end

  def cases_among_house_to_house_tb_screening
    h2h_referrals = source_of_referral('House to house TB screening')
    enrolled.where(patient_id: h2h_referrals).distinct
  end

  def cases_among_mobile_diagnostic_units
    mdu_referrals = source_of_referral('Mobile diagnostic unit')
    enrolled.where(patient_id: mdu_referrals).distinct
  end

  private

  def presumptives
    TbService::TbQueries::PresumptivePatientsQuery.new.ref(@start_date, @end_date)
  end

  def enrolled
    TbService::TbQueries::EnrolledPatientsQuery.new.ref(@start_date, @end_date)
  end

  def source_of_referral (src)
    Patient.joins(encounters: :observations)\
                            .where(encounter: { program_id: program('TB Program'),
                                                encounter_type: encounter_type('TB_Initial'),
                                                encounter_datetime: @start_date..@end_date },
                                   obs: { concept_id: concept('Source of referral'),
                                          value_coded: concept(src) })
  end
end