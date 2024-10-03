class FlagPotentialDuplicatesJob < ApplicationJob
  queue_as :default

  def perform(*args)
    # Do something later
    PotentialDuplicateFinderService.duplicates_finder
  end
end
