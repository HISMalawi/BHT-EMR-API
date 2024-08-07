# -*- encoding: utf-8 -*-
# stub: rswag-ui 2.13.0 ruby lib

Gem::Specification.new do |s|
  s.name = "rswag-ui".freeze
  s.version = "2.13.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Richie Morris".freeze, "Greg Myers".freeze, "Jay Danielian".freeze]
  s.date = "2023-11-29"
  s.description = "Expose beautiful API documentation, powered by Swagger JSON endpoints, including a UI to explore and test operations. More about the OpenAPI initiative here: http://spec.openapis.org/".freeze
  s.email = ["domaindrivendev@gmail.com".freeze]
  s.homepage = "https://github.com/rswag/rswag".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.4.1".freeze
  s.summary = "A Rails Engine that includes swagger-ui and powers it from configured OpenAPI (formerly named Swagger) endpoints".freeze

  s.installed_by_version = "3.4.1" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<actionpack>.freeze, [">= 3.1", "< 7.2"])
  s.add_runtime_dependency(%q<railties>.freeze, [">= 3.1", "< 7.2"])
  s.add_development_dependency(%q<simplecov>.freeze, ["= 0.21.2"])
end
