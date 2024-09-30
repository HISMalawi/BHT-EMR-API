# frozen_string_literal: true

class ApkController < ApplicationController
  skip_before_action :authenticate

  def download
    # get the version from the request
    version = params[:version]
    # check if the version is provided
    if version.nil?
      render json: { status: 'Error', error: 'Version not provided' }
      return
    end
    send_file "/var/www/EMR-APK/EMR-#{version}.apk", type: 'application/vnd.android.package-archive', filename: "EMR-#{version}.apk"
  rescue StandardError => e
    logger.error "APK not found: #{e}"
    render json: {
      status: 'APK not found',
      error: 'APK not found. Please check the path /var/www/EMR-APK/'
    }
  end


  
  # Read the available apk version
  # 
  # latest apk version is stored as /var/www/EMR-APK/EMR-[version].apk
  # e.g. /var/www/EMR-APK/EMR-v2024.Q3.R3.apk where v2024.Q3.R3 is the version
  #
  # @return [JSON] The version of the system 
  def version
    # read the version of the apk file
    tag = `ls /var/www/EMR-APK/EMR-*.apk | awk -F'/' '{print $NF}' | awk -F'-' '{print $2}' | sed 's/.apk$//'`.chomp
    render json: { 'version': tag }

  rescue StandardError => e
    logger.error "APK not found: #{e}"
    render json: { 
      status: 'APK not found', 
      error: 'APK not found. Please check the path /var/www/EMR-APK/' 
    }
  end

end
