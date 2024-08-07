# -*- encoding: utf-8 -*-
# stub: net-protocol 0.1.2 ruby lib

Gem::Specification.new do |s|
  s.name = "net-protocol".freeze
  s.version = "0.1.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "homepage_uri" => "https://github.com/ruby/net-protocol", "source_code_uri" => "https://github.com/ruby/net-protocol" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Yukihiro Matsumoto".freeze]
  s.bindir = "exe".freeze
  s.date = "2021-10-21"
  s.description = "The abstruct interface for net-* client.".freeze
  s.email = ["matz@ruby-lang.org".freeze]
  s.homepage = "https://github.com/ruby/net-protocol".freeze
  s.licenses = ["Ruby".freeze, "BSD-2-Clause".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.3.0".freeze)
  s.rubygems_version = "3.0.8".freeze
  s.summary = "The abstruct interface for net-* client.".freeze

  s.installed_by_version = "3.0.8" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<timeout>.freeze, [">= 0"])
      s.add_runtime_dependency(%q<io-wait>.freeze, [">= 0"])
    else
      s.add_dependency(%q<timeout>.freeze, [">= 0"])
      s.add_dependency(%q<io-wait>.freeze, [">= 0"])
    end
  else
    s.add_dependency(%q<timeout>.freeze, [">= 0"])
    s.add_dependency(%q<io-wait>.freeze, [">= 0"])
  end
end
