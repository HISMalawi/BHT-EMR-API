# -*- encoding: utf-8 -*-
# stub: passenger 6.0.10 ruby src/ruby_supportlib
# stub: src/helper-scripts/download_binaries/extconf.rb

Gem::Specification.new do |s|
  s.name = "passenger".freeze
  s.version = "6.0.10"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "bug_tracker_uri" => "https://github.com/phusion/passenger/issues", "changelog_uri" => "https://github.com/phusion/passenger/blob/stable-6.0/CHANGELOG", "documentation_uri" => "https://www.phusionpassenger.com/docs/", "homepage_uri" => "https://www.phusionpassenger.com/", "mailing_list_uri" => "https://www.phusionpassenger.com/contact", "source_code_uri" => "https://github.com/phusion/passenger", "wiki_uri" => "https://github.com/phusion/passenger/wiki" } if s.respond_to? :metadata=
  s.require_paths = ["src/ruby_supportlib".freeze]
  s.authors = ["Phusion - http://www.phusion.nl/".freeze]
  s.date = "2021-07-12"
  s.description = "A modern web server and application server for Ruby, Python and Node.js, optimized for performance, low memory usage and ease of use.".freeze
  s.email = "software-signing@phusion.nl".freeze
  s.executables = ["passenger".freeze, "passenger-install-apache2-module".freeze, "passenger-install-nginx-module".freeze, "passenger-config".freeze, "passenger-status".freeze, "passenger-memory-stats".freeze]
  s.extensions = ["src/helper-scripts/download_binaries/extconf.rb".freeze]
  s.files = ["bin/passenger".freeze, "bin/passenger-config".freeze, "bin/passenger-install-apache2-module".freeze, "bin/passenger-install-nginx-module".freeze, "bin/passenger-memory-stats".freeze, "bin/passenger-status".freeze, "src/helper-scripts/download_binaries/extconf.rb".freeze]
  s.homepage = "https://www.phusionpassenger.com/".freeze
  s.rubygems_version = "3.1.4".freeze
  s.summary = "A fast and robust web server and application server for Ruby, Python and Node.js".freeze

  s.installed_by_version = "3.1.4" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_runtime_dependency(%q<rake>.freeze, [">= 0.8.1"])
    s.add_runtime_dependency(%q<rack>.freeze, [">= 0"])
  else
    s.add_dependency(%q<rake>.freeze, [">= 0.8.1"])
    s.add_dependency(%q<rack>.freeze, [">= 0"])
  end
end
