# -*- encoding: utf-8 -*-
# stub: emr_ohsp_interface 2.2.2 ruby lib

Gem::Specification.new do |s|
  s.name = "emr_ohsp_interface".freeze
  s.version = "2.2.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "homepage_uri" => "https://github.com/LUKEINTERNATIONAL/emr_OHSP_interface" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Justin Manda, Petros Kayange, Dominic Kasanga".freeze]
  s.date = "2023-09-25"
  s.email = ["justinmandah@gmail.com, kayangepetros@gmail.com, dominickasanga@gmail.com".freeze]
  s.homepage = "https://github.com/LUKEINTERNATIONAL/emr_OHSP_interface".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.4.1".freeze
  s.summary = "This in a gem that facilitates interfacing of EMR, One Health Surveillance Platform and Lims".freeze

  s.installed_by_version = "3.4.1" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<rails>.freeze, ["~> 7.0.6"])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 3.0"])
  s.add_development_dependency(%q<rest-client>.freeze, ["~> 2.1"])
  s.add_development_dependency(%q<mysql2>.freeze, ["~> 0"])
  s.add_development_dependency(%q<sqlite3>.freeze, [">= 1.3.6", "~> 1.3"])
end
