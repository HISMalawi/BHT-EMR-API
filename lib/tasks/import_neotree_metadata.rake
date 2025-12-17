# frozen_string_literal: true

require 'neotree_metadata/loader'

namespace :neotree do
  desc 'Import Neotree metadata from lib/data as concepts and answers'
  task import_metadata: :environment do
    NeotreeMetadata::Loader.new.load!
  end
end
