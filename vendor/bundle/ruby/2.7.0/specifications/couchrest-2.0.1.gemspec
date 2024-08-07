# -*- encoding: utf-8 -*-
# stub: couchrest 2.0.1 ruby lib

Gem::Specification.new do |s|
  s.name = "couchrest".freeze
  s.version = "2.0.1"

  s.required_rubygems_version = Gem::Requirement.new("> 1.3.1".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["J. Chris Anderson".freeze, "Matt Aimonetti".freeze, "Marcos Tapajos".freeze, "Will Leinweber".freeze, "Sam Lown".freeze]
  s.date = "2017-02-13"
  s.description = "CouchRest provides a simple interface on top of CouchDB's RESTful HTTP API, as well as including some utility scripts for managing views and attachments.".freeze
  s.email = "me@samlown.com".freeze
  s.extra_rdoc_files = ["LICENSE".freeze, "README.md".freeze, "THANKS.md".freeze]
  s.files = ["LICENSE".freeze, "README.md".freeze, "THANKS.md".freeze]
  s.homepage = "http://github.com/couchrest/couchrest".freeze
  s.licenses = ["Apache License 2.0".freeze]
  s.rdoc_options = ["--charset=UTF-8".freeze]
  s.rubygems_version = "3.1.4".freeze
  s.summary = "Lean and RESTful interface to CouchDB.".freeze

  s.installed_by_version = "3.1.4" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_runtime_dependency(%q<httpclient>.freeze, ["~> 2.8"])
    s.add_runtime_dependency(%q<multi_json>.freeze, ["~> 1.7"])
    s.add_runtime_dependency(%q<mime-types>.freeze, [">= 1.15"])
    s.add_development_dependency(%q<bundler>.freeze, ["~> 1.3"])
    s.add_development_dependency(%q<rspec>.freeze, ["~> 2.14.1"])
    s.add_development_dependency(%q<rake>.freeze, ["< 11.0"])
    s.add_development_dependency(%q<webmock>.freeze, [">= 0"])
  else
    s.add_dependency(%q<httpclient>.freeze, ["~> 2.8"])
    s.add_dependency(%q<multi_json>.freeze, ["~> 1.7"])
    s.add_dependency(%q<mime-types>.freeze, [">= 1.15"])
    s.add_dependency(%q<bundler>.freeze, ["~> 1.3"])
    s.add_dependency(%q<rspec>.freeze, ["~> 2.14.1"])
    s.add_dependency(%q<rake>.freeze, ["< 11.0"])
    s.add_dependency(%q<webmock>.freeze, [">= 0"])
  end
end
