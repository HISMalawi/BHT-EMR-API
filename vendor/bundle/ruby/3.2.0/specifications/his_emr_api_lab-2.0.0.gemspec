# -*- encoding: utf-8 -*-
# stub: his_emr_api_lab 2.0.0 ruby lib

Gem::Specification.new do |s|
  s.name = "his_emr_api_lab".freeze
  s.version = "2.0.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "rubygems_mfa_required" => "true", "source_code_uri" => "https://github.com/EGPAFMalawiHIS/his_emr_api_lab" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Elizabeth Glaser Pediatric Foundation Malawi".freeze]
  s.date = "2024-04-02"
  s.description = "This adds a lab interface to the OpenMRS compatible core API provided by\n[HIS-EMR-API](https://github.com/EGPAFMalawiHIS/HIS-EMR-API).\n".freeze
  s.email = ["emrdevelopersmalawi@pedaids.org".freeze]
  s.homepage = "https://github.com/EGPAFMalawiHIS/his_emr_api_lab".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.4.1".freeze
  s.summary = "Lab extension for the HIS-EMR-API".freeze

  s.installed_by_version = "3.4.1" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<couchrest>.freeze, ["~> 2.0.0"])
  s.add_runtime_dependency(%q<parallel>.freeze, ["~> 1.20.1"])
  s.add_runtime_dependency(%q<rails>.freeze, ["~> 7.0.6"])
  s.add_runtime_dependency(%q<socket.io-client-simple>.freeze, ["~> 1.2.1"])
  s.add_development_dependency(%q<bcrypt>.freeze, ["~> 3.1.0"])
  s.add_development_dependency(%q<factory_bot_rails>.freeze, ["~> 6.1.0"])
  s.add_development_dependency(%q<faker>.freeze, ["~> 2.16.0"])
  s.add_development_dependency(%q<rspec-rails>.freeze, ["~> 5.0.0"])
  s.add_development_dependency(%q<rswag-api>.freeze, ["~> 2.5.1"])
  s.add_development_dependency(%q<rswag-specs>.freeze, ["~> 2.5.1"])
  s.add_development_dependency(%q<rswag-ui>.freeze, ["~> 2.5.1"])
  s.add_development_dependency(%q<rubocop>.freeze, ["~> 0.79.0"])
  s.add_development_dependency(%q<rubocop-rspec>.freeze, ["~> 1.41.0"])
  s.add_development_dependency(%q<shoulda-matchers>.freeze, ["~> 4.5.0"])
  s.add_development_dependency(%q<sqlite3>.freeze, ["~> 1.4.0"])
end
