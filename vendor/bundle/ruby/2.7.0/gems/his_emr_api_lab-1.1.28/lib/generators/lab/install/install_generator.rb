# frozen_string_literal: true

module Lab
  class InstallGenerator < Rails::Generators::Base
    source_root File.expand_path('templates', __dir__)

    def copy_openapi_docs
      copy_file('swagger.yaml', 'swagger/lab/v1/swagger.yaml')
    end

    def copy_rswag_initializer
      copy_file('rswag-ui-lab.rb', 'config/initializers/rswag-ui-lab.rb')
    end

    def copy_worker
      copy_file('start_worker.rb', 'bin/lab/start_worker.rb')
    end
  end
end
