# -*- encoding: utf-8 -*-
# stub: his_emr_api_lab 1.1.28 ruby lib

Gem::Specification.new do |s|
  s.name = "his_emr_api_lab".freeze
  s.version = "1.1.28"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "source_code_uri" => "https://github.com/EGPAFMalawiHIS/his_emr_api_lab" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Elizabeth Glaser Pediatric Foundation Malawi".freeze]
  s.date = "2023-03-15"
  s.description = "This adds a lab interface to the OpenMRS compatible core API provided by\n[HIS-EMR-API](https://github.com/EGPAFMalawiHIS/HIS-EMR-API).\n".freeze
  s.email = ["emrdevelopersmalawi@pedaids.org".freeze]
  s.homepage = "https://github.com/EGPAFMalawiHIS/his_emr_api_lab".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.1.4".freeze
  s.summary = "Lab extension for the HIS-EMR-API".freeze

  s.installed_by_version = "3.1.4" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_runtime_dependency(%q<couchrest>.freeze, ["~> 2.0.0"])
    s.add_runtime_dependency(%q<parallel>.freeze, ["~> 1.20.1"])
    s.add_runtime_dependency(%q<rails>.freeze, ["~> 5.2.4", ">= 5.2.4.3"])
    s.add_runtime_dependency(%q<socket.io-client-simple>.freeze, ["~> 1.2.1"])
    s.add_development_dependency(%q<bcrypt>.freeze, ["~> 3.1.0"])
    s.add_development_dependency(%q<factory_bot_rails>.freeze, ["~> 6.1.0"])
    s.add_development_dependency(%q<faker>.freeze, ["~> 2.16.0"])
    s.add_development_dependency(%q<rspec-rails>.freeze, ["~> 5.0.0"])
    s.add_development_dependency(%q<rswag-api>.freeze, ["~> 2.4.0"])
    s.add_development_dependency(%q<rswag-specs>.freeze, ["~> 2.4.0"])
    s.add_development_dependency(%q<rswag-ui>.freeze, ["~> 2.4.0"])
    s.add_development_dependency(%q<rubocop>.freeze, ["~> 0.79.0"])
    s.add_development_dependency(%q<rubocop-rspec>.freeze, ["~> 1.41.0"])
    s.add_development_dependency(%q<shoulda-matchers>.freeze, ["~> 4.5.0"])
    s.add_development_dependency(%q<sqlite3>.freeze, ["~> 1.4.0"])
  else
    s.add_dependency(%q<couchrest>.freeze, ["~> 2.0.0"])
    s.add_dependency(%q<parallel>.freeze, ["~> 1.20.1"])
    s.add_dependency(%q<rails>.freeze, ["~> 5.2.4", ">= 5.2.4.3"])
    s.add_dependency(%q<socket.io-client-simple>.freeze, ["~> 1.2.1"])
    s.add_dependency(%q<bcrypt>.freeze, ["~> 3.1.0"])
    s.add_dependency(%q<factory_bot_rails>.freeze, ["~> 6.1.0"])
    s.add_dependency(%q<faker>.freeze, ["~> 2.16.0"])
    s.add_dependency(%q<rspec-rails>.freeze, ["~> 5.0.0"])
    s.add_dependency(%q<rswag-api>.freeze, ["~> 2.4.0"])
    s.add_dependency(%q<rswag-specs>.freeze, ["~> 2.4.0"])
    s.add_dependency(%q<rswag-ui>.freeze, ["~> 2.4.0"])
    s.add_dependency(%q<rubocop>.freeze, ["~> 0.79.0"])
    s.add_dependency(%q<rubocop-rspec>.freeze, ["~> 1.41.0"])
    s.add_dependency(%q<shoulda-matchers>.freeze, ["~> 4.5.0"])
    s.add_dependency(%q<sqlite3>.freeze, ["~> 1.4.0"])
  end
end
