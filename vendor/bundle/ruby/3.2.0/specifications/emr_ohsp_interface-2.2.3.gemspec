# -*- encoding: utf-8 -*-
# stub: emr_ohsp_interface 2.2.3 ruby lib

Gem::Specification.new do |s|
  s.name = "emr_ohsp_interface".freeze
  s.version = "2.2.3".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "homepage_uri" => "https://github.com/LUKEINTERNATIONAL/emr_OHSP_interface" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Justin Manda, Petros Kayange, Dominic Kasanga".freeze]
  s.date = "2024-05-11"
  s.email = ["justinmandah@gmail.com, kayangepetros@gmail.com, dominickasanga@gmail.com".freeze]
  s.homepage = "https://github.com/LUKEINTERNATIONAL/emr_OHSP_interface".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.5.9".freeze
  s.summary = "This in a gem that facilitates interfacing of EMR, One Health Surveillance Platform and Lims".freeze

  s.installed_by_version = "3.5.9".freeze if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<rails>.freeze, ["~> 7.0.6".freeze])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 3.0".freeze])
  s.add_development_dependency(%q<rest-client>.freeze, ["~> 2.1".freeze])
  s.add_development_dependency(%q<mysql2>.freeze, ["~> 0".freeze])
  s.add_development_dependency(%q<sqlite3>.freeze, [">= 1.3.6".freeze, "~> 1.3".freeze])
end
