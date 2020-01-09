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

  def version
    begin
      render json: {'System version': File.read("#{Rails.root}/HEAD").gsub("\n","")}
    rescue
      render json: {status: 'Head not set. Please run: git describe --tags > HEAD in BHT-EMR-API root folder.', 
        error: "No Head containing tag description found"}
    end
  end

  def database_backup_files
    begin
      global_property =  GlobalProperty.find_by(property: 'backup.path')
      files = %x|ls -lh #{global_property.property_value}/*sql*|
      render json: {'Backup file(s)':  files.split("\n")}
    rescue
      render json: {status: 'Backup(s) not found.', 
        error: "Backup folder not found.Maybe the path is not set"}
    end
  end

  def user_system_usage
    start_date = params[:start_date].to_date.strftime("%Y-%m-%d 00:00:00")
    end_date = params[:end_date].to_date.strftime("%Y-%m-%d 23:59:59")
    program_id = params[:program_id]

    usage = ActiveRecord::Base.connection.select_all <<EOF
    SELECT 
      username, given_name, family_name, u.date_created,
      r.role, COUNT(encounter_id) encounters FROM encounter e
    INNER JOIN users u On u.user_id = e.creator 
    LEFT JOIN person_name n ON n.person_id = u.person_id AND n.voided = 0
    LEFT JOIN user_role r ON r.user_id = u.user_id
    WHERE e.voided = 0 AND e.encounter_datetime BETWEEN '#{start_date}' AND '#{end_date}'
    AND e.program_id = #{program_id} GROUP BY username;
EOF

    counts = []
    (usage || []).each do |e|
      counts << {
        username: e['username'],
        given_name: e['given_name'],
        family_name: e['family_name'],
        role: e['role'],
        registered_on: e['date_created'],
        encounters: e['encounters']
      }
    end

    render json: counts
  end

end
