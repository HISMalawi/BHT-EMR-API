source_root = File.expand_path(File.dirname(__FILE__))
$LOAD_PATH.unshift("#{source_root}/src/ruby_supportlib")
require 'phusion_passenger'
PhusionPassenger.locate_directories
PhusionPassenger.require_passenger_lib 'packaging'

Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY
  s.homepage = "https://www.phusionpassenger.com/"
  s.summary = "A fast and robust web server and application server for Ruby, Python and Node.js"
  s.name = PhusionPassenger::PACKAGE_NAME
  s.version = PhusionPassenger::VERSION_STRING
  s.author = "Phusion - http://www.phusion.nl/"
  s.email = "software-signing@phusion.nl"
  s.require_paths = ["src/ruby_supportlib"]
  s.metadata = {
    "bug_tracker_uri"   => "https://github.com/phusion/passenger/issues",
    "changelog_uri"     => "https://github.com/phusion/passenger/blob/stable-#{PhusionPassenger::VERSION_STRING.split('.').slice(0,2).join('.')}/CHANGELOG",
    "documentation_uri" => "https://www.phusionpassenger.com/docs/",
    "homepage_uri"      => "https://www.phusionpassenger.com/",
    "source_code_uri"   => "https://github.com/phusion/passenger",
    "mailing_list_uri"  => "https://www.phusionpassenger.com/contact",
    "wiki_uri"          => "https://github.com/phusion/passenger/wiki"
  }
  s.add_dependency 'rake', '>= 0.8.1'
  s.add_dependency 'rack'
  s.files = Dir[*PhusionPassenger::Packaging::GLOB] -
    Dir[*PhusionPassenger::Packaging::EXCLUDE_GLOB]
  s.executables = PhusionPassenger::Packaging::USER_EXECUTABLES +
    PhusionPassenger::Packaging::SUPER_USER_EXECUTABLES
  s.description = "A modern web server and application server for Ruby, Python and Node.js, " +
    "optimized for performance, low memory usage and ease of use."

  if ENV['OFFICIAL_RELEASE']
    s.extensions = ["src/helper-scripts/download_binaries/extconf.rb"]
  end
end
