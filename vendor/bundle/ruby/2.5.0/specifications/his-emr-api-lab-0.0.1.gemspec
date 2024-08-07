# -*- encoding: utf-8 -*-
# stub: his-emr-api-lab 0.0.1 ruby lib

Gem::Specification.new do |s|
  s.name = "his-emr-api-lab".freeze
  s.version = "0.0.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "source_code_uri" => "https://github.com/EGPAFMalawiHIS/his-emr-api-Lab" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Elizabeth Glaser Pediatric Foundation Malawi".freeze]
  s.date = "2021-03-27"
  s.description = "This adds a lab interface to the OpenMRS compatible core API provided by\n[HIS-EMR-API](https://github.com/EGPAFMalawiHIS/HIS-EMR-API).\n".freeze
  s.email = ["emrdevelopersmalawi@pedaids.org".freeze]
  s.homepage = "https://github.com/EGPAFMalawiHIS/his-emr-api-Lab".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.0.8".freeze
  s.summary = "Lab extension for the HIS-EMR-API".freeze

  s.installed_by_version = "3.0.8" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<couchrest>.freeze, [">= 0"])
      s.add_runtime_dependency(%q<rails>.freeze, ["~> 5.2.4", ">= 5.2.4.3"])
      s.add_development_dependency(%q<bcrypt>.freeze, [">= 0"])
      s.add_development_dependency(%q<factory_bot_rails>.freeze, [">= 0"])
      s.add_development_dependency(%q<faker>.freeze, [">= 0"])
      s.add_development_dependency(%q<rspec-rails>.freeze, [">= 0"])
      s.add_development_dependency(%q<rswag-api>.freeze, [">= 0"])
      s.add_development_dependency(%q<rswag-specs>.freeze, [">= 0"])
      s.add_development_dependency(%q<rswag-ui>.freeze, [">= 0"])
      s.add_development_dependency(%q<rubocop>.freeze, ["~> 0.79.0"])
      s.add_development_dependency(%q<rubocop-rspec>.freeze, [">= 0"])
      s.add_development_dependency(%q<shoulda-matchers>.freeze, [">= 0"])
      s.add_development_dependency(%q<sqlite3>.freeze, [">= 0"])
    else
      s.add_dependency(%q<couchrest>.freeze, [">= 0"])
      s.add_dependency(%q<rails>.freeze, ["~> 5.2.4", ">= 5.2.4.3"])
      s.add_dependency(%q<bcrypt>.freeze, [">= 0"])
      s.add_dependency(%q<factory_bot_rails>.freeze, [">= 0"])
      s.add_dependency(%q<faker>.freeze, [">= 0"])
      s.add_dependency(%q<rspec-rails>.freeze, [">= 0"])
      s.add_dependency(%q<rswag-api>.freeze, [">= 0"])
      s.add_dependency(%q<rswag-specs>.freeze, [">= 0"])
      s.add_dependency(%q<rswag-ui>.freeze, [">= 0"])
      s.add_dependency(%q<rubocop>.freeze, ["~> 0.79.0"])
      s.add_dependency(%q<rubocop-rspec>.freeze, [">= 0"])
      s.add_dependency(%q<shoulda-matchers>.freeze, [">= 0"])
      s.add_dependency(%q<sqlite3>.freeze, [">= 0"])
    end
  else
    s.add_dependency(%q<couchrest>.freeze, [">= 0"])
    s.add_dependency(%q<rails>.freeze, ["~> 5.2.4", ">= 5.2.4.3"])
    s.add_dependency(%q<bcrypt>.freeze, [">= 0"])
    s.add_dependency(%q<factory_bot_rails>.freeze, [">= 0"])
    s.add_dependency(%q<faker>.freeze, [">= 0"])
    s.add_dependency(%q<rspec-rails>.freeze, [">= 0"])
    s.add_dependency(%q<rswag-api>.freeze, [">= 0"])
    s.add_dependency(%q<rswag-specs>.freeze, [">= 0"])
    s.add_dependency(%q<rswag-ui>.freeze, [">= 0"])
    s.add_dependency(%q<rubocop>.freeze, ["~> 0.79.0"])
    s.add_dependency(%q<rubocop-rspec>.freeze, [">= 0"])
    s.add_dependency(%q<shoulda-matchers>.freeze, [">= 0"])
    s.add_dependency(%q<sqlite3>.freeze, [">= 0"])
  end
end
