# frozen_string_literal: true

if File.exist?('config/application.yml') &&
  File.read('config/application.yml').include?('password_reset')
  return
end

cmd = 'echo -e "\npassword_reset:\n  secret_key: CENTRALISED-EMR" >> config/application.yml'
system(cmd) || return
