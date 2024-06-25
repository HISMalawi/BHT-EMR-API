desc 'Generate openapi/swagger documentation template in engine'
task :swag, ['app:rswag:specs:swaggerize'] do
  source = 'spec/dummy/swagger/v1/swagger.yaml'
  destination = 'lib/generators/lab/install/templates/swagger.yaml'

  FileUtils.copy(source, destination)
end

namespace :lab do
  desc 'Install Lab engine into container application'
  task :install do
    sh 'rails generate lab:install'
    sh 'rake lab:install:migrations'
  end

  desc 'Uninstall Lab engine from container application'
  task :uninstall do
    sh 'rails destroy lab:install'
  end

  desc 'Load Lab metadata into database'
  task :load_metadata do
    sh "rails r #{__dir__}/loaders/metadata_loader.rb"
  end
end
