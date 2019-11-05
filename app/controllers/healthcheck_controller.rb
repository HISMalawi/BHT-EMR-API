# frozen_string_literal: true

# Check that the database and other dependencies are available
class HealthcheckController < ApplicationController
  skip_before_action :authenticate

  def index
    ActiveRecord::Base.connection.execute('SELECT VERSION()')
    render json: { status: 'Up' }
  rescue StandardError => e
    logger.error "Database unreachable: #{e}"
    render json: { status: 'Down', error: 'Database unreachable' }
  end

  def temp_earliest_start_table_exisit
    ActiveRecord::Base.connection.execute('SELECT * FROM temp_earliest_start_date')
    render json: { status: 'Up' }
  rescue StandardError => e
    logger.error "Table unreachable: #{e}"
    render json: { status: 'Down', error: 'Database table unreachable' }
  end

end
