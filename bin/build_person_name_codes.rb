# frozen_string_literal: true

require 'logger'

LOGGER = Logger.new(STDIN)
ActiveRecord::Base.logger = LOGGER

BATCH_SIZE = 1000
TOTAL_NAMES = NameSearchService.unindexed_person_names.count

(1..TOTAL_NAMES).step(BATCH_SIZE).each do |offset|
  unindexed_names = NameSearchService.unindexed_person_names.offset(offset).limit(BATCH_SIZE)
  break if unindexed_names.count.zero?

  unindexed_names.each do |name|
    NameSearchService.index_person_name(name)
  end
end
