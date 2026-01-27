namespace :sync do
  desc "Run all sync jobs in parallel"
  task all: :environment do
    jobs = [
      Sync::BatchPatientSyncJob,
      Sync::SpecimenSyncJob,
      Sync::StageSyncJob,
      Sync::StockSyncJob,
      Sync::TestResultIndicatorsSyncJob,
      Sync::TestTypesSyncJob,
      Sync::ConceptNameSyncJob,
      Sync::ConceptSetSyncJob,
      Sync::DdeIdsSyncJob,
      Sync::DistrictSyncJob,
      Sync::DrugSyncJob,
      Sync::ProgramSyncJob,
      Sync::RelationshipTypeSyncJob,
      Sync::TraditionalAuthoritySyncJob,
      Sync::VillageSyncJob,
      Sync::VisitSyncJob,
      Sync::WardSyncJob,
      Sync::FacilitySyncJob,
      Sync::TestTypesSyncJob
    ]

    jobs.each(&:perform_async)
    puts "✅ Enqueued #{jobs.size} sync jobs in parallel."
  end

  desc "Run a specific sync job by name. Example: rails sync:run[StageSyncJob]"
  task :run, [:job_name] => :environment do |t, args|
    if args[:job_name].blank?
      puts "⚠️  Please provide a job name. Example: rails sync:run[StageSyncJob]"
      next
    end

    begin
      job_class = "Sync::#{args[:job_name]}".constantize
      job_class.perform_async
      puts "✅ Enqueued #{job_class}"
    rescue NameError
      puts "❌ Job Sync::#{args[:job_name]} not found."
    end
  end
end
