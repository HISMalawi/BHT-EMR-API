class Api::V1::ImmunizationReportController < ApplicationController
  before_action :report_params , only: [:stats, :vaccines_administered]

  def stats
    DashboardStatsJob.perform_later(User.current.location_id)
  end

  def drugs
    drugs = ConceptSet.joins(concept: %i[concept_names drugs])
                      .where(concept_set: ConceptName.where(name: 'Immunizations').pluck(:concept_id))
                      .group('concept.concept_id, drug.name, drug.drug_id')
                      .select('concept.concept_id, drug.name as name, drug.drug_id drug_id')
    
    render json: drugs
  end

  def under_five_immunizations_drugs
    render json: ConceptName.joins("INNER JOIN concept_set s ON s.concept_id = concept_name.concept_id")
                            .joins("INNER JOIN drug ON drug.concept_id = concept_name.concept_id")
                            .where("s.concept_set = ? AND concept_name.name LIKE ? AND drug.retired = 0", 11894, "%#{params[:name]}%")
                            .group('concept_name.concept_id', 'drug.drug_id')
                            .select('concept_name.concept_id, concept_name.concept_name_id, drug.name, drug.drug_id')
  end

  def vaccines_administered
    start_date = report_params[:start_date]
    end_date = report_params[:end_date]

    # Get the current location id
    location_id = User.current.location_id

    vaccines_administered_service = ImmunizationService::Reports::General::VaccinesAdministered.new(start_date:,
                                                                                                    end_date:,
                                                                                                    location_id:)
    data = vaccines_administered_service.data

    render json: data
  end

  def aefi_report
    start_date = report_params[:start_date]
    end_date = report_params[:end_date]

    # Get the current location id
    location_id = User.current.location_id

    aefi_service = ImmunizationService::Reports::General::AefiReport.new(start_date:,
                                                                          end_date:,
                                                                          location_id:)
    data = aefi_service.data

    render json: data
  end

  def months_picker
    render json: months_generator
  end

  def weeks_picker
    render json: weeks_generator
  end

  def months_generator
    months = {}
      count = 1
      curr_date = Date.today

      while count < 13
        curr_date -= 1.month
        months[curr_date.strftime('%Y/%m')] = [
          curr_date.strftime('%B-%Y'),
          "#{curr_date.beginning_of_month} to #{curr_date.end_of_month}"
        ]
        count += 1
      end

      months.to_a
  end

  def weeks_generator
    weeks = {}
      first_day = (Date.today - 11.months).at_beginning_of_month
      add_initial_week(weeks, first_day)

      first_monday = first_day.next_week(:monday)

      while first_monday <= Date.today
        add_week(weeks, first_monday)
        first_monday += 7
      end

      this_wk = "#{Date.today.year}W#{Date.today.cweek}"
      weeks.reject { |key, _| key == this_wk }.to_a
  end

    # Adds the initial week to the weeks hash.
    # @param weeks [Hash] The hash to add the week to
    # @param first_day [Date] The first day of the initial week
  def add_initial_week(weeks, first_day)
    wk_of_first_day = first_day.cweek
      return unless wk_of_first_day > 1

      wk = "#{first_day.prev_year.year}W#{wk_of_first_day}"
      dates = "#{first_day - first_day.wday + 1} to #{first_day - first_day.wday + 1 + 6}"
      weeks[wk] = dates
  end

    # Adds a week to the weeks hash.
    # @param weeks [Hash] The hash to add the week to
    # @param first_monday [Date] The first Monday of the week
  def add_week(weeks, first_monday)
    wk = "#{first_monday.year}W#{first_monday.cweek}"
      dates = "#{first_monday} to #{first_monday + 6}"
      weeks[wk] = dates
  end

  private

  def report_params
    params.require(%i[start_date end_date])
    params.permit(%i[start_date end_date])
  end
end
