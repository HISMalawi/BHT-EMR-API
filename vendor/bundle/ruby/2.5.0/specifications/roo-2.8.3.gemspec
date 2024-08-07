# -*- encoding: utf-8 -*-
# stub: roo 2.8.3 ruby lib

Gem::Specification.new do |s|
  s.name = "roo".freeze
  s.version = "2.8.3"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Thomas Preymesser".freeze, "Hugh McGowan".freeze, "Ben Woosley".freeze, "Oleksandr Simonov".freeze, "Steven Daniels".freeze, "Anmol Chopra".freeze]
  s.date = "2020-02-03"
  s.description = "Roo can access the contents of various spreadsheet files. It can handle\n* OpenOffice\n* Excelx\n* LibreOffice\n* CSV".freeze
  s.email = ["ruby.ruby.ruby.roo@gmail.com".freeze, "oleksandr@simonov.me".freeze]
  s.homepage = "https://github.com/roo-rb/roo".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.3.0".freeze)
  s.rubygems_version = "3.0.8".freeze
  s.summary = "Roo can access the contents of various spreadsheet files.".freeze

  s.installed_by_version = "3.0.8" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<nokogiri>.freeze, ["~> 1"])
      s.add_runtime_dependency(%q<rubyzip>.freeze, [">= 1.3.0", "< 3.0.0"])
      s.add_development_dependency(%q<rake>.freeze, ["~> 10.1"])
      s.add_development_dependency(%q<minitest>.freeze, ["~> 5.4", ">= 5.4.3"])
      s.add_development_dependency(%q<rack>.freeze, ["~> 1.6", "< 2.0.0"])
    else
      s.add_dependency(%q<nokogiri>.freeze, ["~> 1"])
      s.add_dependency(%q<rubyzip>.freeze, [">= 1.3.0", "< 3.0.0"])
      s.add_dependency(%q<rake>.freeze, ["~> 10.1"])
      s.add_dependency(%q<minitest>.freeze, ["~> 5.4", ">= 5.4.3"])
      s.add_dependency(%q<rack>.freeze, ["~> 1.6", "< 2.0.0"])
    end
  else
    s.add_dependency(%q<nokogiri>.freeze, ["~> 1"])
    s.add_dependency(%q<rubyzip>.freeze, [">= 1.3.0", "< 3.0.0"])
    s.add_dependency(%q<rake>.freeze, ["~> 10.1"])
    s.add_dependency(%q<minitest>.freeze, ["~> 5.4", ">= 5.4.3"])
    s.add_dependency(%q<rack>.freeze, ["~> 1.6", "< 2.0.0"])
  end
end
