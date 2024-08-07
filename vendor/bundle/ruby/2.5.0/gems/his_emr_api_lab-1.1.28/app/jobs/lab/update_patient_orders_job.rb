# frozen_string_literal: true

module Lab
  ##
  # Fetches updates on a patient's orders from external sources.
  class UpdatePatientOrdersJob < ApplicationJob
    queue_as :default

    def perform(patient_id)
      Rails.logger.info('Initialising LIMS REST API...')

      User.current = Lab::Lims::Utils.lab_user
      Location.current = Location.find_by_name('ART clinic')

      lockfile = Rails.root.join('tmp', "update-patient-orders-#{patient_id}.lock")

      done = File.open(lockfile, File::RDWR | File::CREAT) do |lock|
        unless lock.flock(File::LOCK_NB | File::LOCK_EX)
          Rails.logger.info('Another update patient job is already running...')
          break false
        end

        worker = Lab::Lims::PullWorker.new(Lab::Lims::ApiFactory.create_api)
        worker.pull_orders(patient_id: patient_id)

        true
      end

      File.unlink(lockfile) if done
    end
  end
end
