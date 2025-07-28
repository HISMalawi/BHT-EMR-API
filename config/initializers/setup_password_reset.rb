# frozen_string_literal: true

# remove -e from the application.yml
command = "sed -i '/^-e\s*$/d' config/application.yml"
system(command) || return

if File.exist?('config/application.yml') &&
  File.read('config/application.yml').include?('password_reset')
  return
end

cmd = 'echo "\npassword_reset:\n  secret_key: CENTRALISED-EMR" >> config/application.yml'
system(cmd) || return
