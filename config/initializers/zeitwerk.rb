# frozen_string_literal: true

Rails.autoloaders.each do |autoloader|
  autoloader.inflector.inflect(
    'bantu_soundex' => 'String',
    'auto12epl' => 'Auto12Epl'
    # 'dde_error' => 'DDEError',
    # 'push_dde_footprints_job' => 'PushDDEFootprintsJob',
    # 'dde_client' => 'DDEClient'
  )
end
