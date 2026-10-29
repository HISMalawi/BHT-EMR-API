namespace :gender do
  GENDER_FIXES = { 'Male' => 'M', 'Female' => 'F' }.freeze

  desc 'Resolves people saved with gender Male/Female (NID integration) to M/F'
  task repair_format: :environment do
    dry_run = ENV['DRY_RUN']&.downcase == 'true'

    puts dry_run ? '=== DRY RUN MODE (no changes will be saved) ===' : '=== LIVE MODE ==='

    GENDER_FIXES.each do |long_form, short_form|
      people = Person.unscoped.where(gender: long_form)
      puts "#{long_form} -> #{short_form}: #{people.count} people found"
      next if dry_run

      updated = people.update_all(gender: short_form, date_changed: Time.now)
      puts "  Updated #{updated} people"
    end
  end
end
