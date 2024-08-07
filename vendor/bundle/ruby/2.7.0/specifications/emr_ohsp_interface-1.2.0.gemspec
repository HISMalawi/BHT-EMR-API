# -*- encoding: utf-8 -*-
# stub: emr_ohsp_interface 1.2.0 ruby lib

Gem::Specification.new do |s|
  s.name = "emr_ohsp_interface".freeze
  s.version = "1.2.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "homepage_uri" => "https://github.com/LUKEINTERNATIONAL/emr_OHSP_interface" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Justin Manda, Petros Kayange, and Dominic Kasanga".freeze]
  s.date = "2023-01-15"
  s.email = ["justinmandah@gmail.com, kayangepetros@gmail.com, dominickasanga@gmail.com".freeze]
  s.homepage = "https://github.com/LUKEINTERNATIONAL/emr_OHSP_interface".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.1.4".freeze
  s.summary = "This in a gem that facilitates interfacing of EMR, One Health Surveillance Platform and Lims".freeze

  s.installed_by_version = "3.1.4" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_runtime_dependency(%q<rails>.freeze, ["~> 5.2.4", ">= 5.2.4.3"])
    s.add_development_dependency(%q<rspec>.freeze, ["~> 3.0"])
    s.add_development_dependency(%q<rest-client>.freeze, ["~> 1"])
    s.add_development_dependency(%q<mysql2>.freeze, ["~> 0"])
    s.add_development_dependency(%q<sqlite3>.freeze, [">= 1.3.6", "~> 1.3"])
  else
    s.add_dependency(%q<rails>.freeze, ["~> 5.2.4", ">= 5.2.4.3"])
    s.add_dependency(%q<rspec>.freeze, ["~> 3.0"])
    s.add_dependency(%q<rest-client>.freeze, ["~> 1"])
    s.add_dependency(%q<mysql2>.freeze, ["~> 0"])
    s.add_dependency(%q<sqlite3>.freeze, [">= 1.3.6", "~> 1.3"])
  end
end
