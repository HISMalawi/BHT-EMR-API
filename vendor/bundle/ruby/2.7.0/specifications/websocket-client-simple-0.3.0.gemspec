# -*- encoding: utf-8 -*-
# stub: websocket-client-simple 0.3.0 ruby lib

Gem::Specification.new do |s|
  s.name = "websocket-client-simple".freeze
  s.version = "0.3.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Sho Hashimoto".freeze]
  s.date = "2016-02-20"
  s.description = "Simple WebSocket Client for Ruby".freeze
  s.email = ["hashimoto@shokai.org".freeze]
  s.homepage = "https://github.com/shokai/websocket-client-simple".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.1.4".freeze
  s.summary = "Simple WebSocket Client for Ruby".freeze

  s.installed_by_version = "3.1.4" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_development_dependency(%q<bundler>.freeze, ["~> 1.3"])
    s.add_development_dependency(%q<rake>.freeze, [">= 0"])
    s.add_development_dependency(%q<minitest>.freeze, [">= 0"])
    s.add_development_dependency(%q<websocket-eventmachine-server>.freeze, [">= 0"])
    s.add_development_dependency(%q<eventmachine>.freeze, [">= 0"])
    s.add_runtime_dependency(%q<websocket>.freeze, [">= 0"])
    s.add_runtime_dependency(%q<event_emitter>.freeze, [">= 0"])
  else
    s.add_dependency(%q<bundler>.freeze, ["~> 1.3"])
    s.add_dependency(%q<rake>.freeze, [">= 0"])
    s.add_dependency(%q<minitest>.freeze, [">= 0"])
    s.add_dependency(%q<websocket-eventmachine-server>.freeze, [">= 0"])
    s.add_dependency(%q<eventmachine>.freeze, [">= 0"])
    s.add_dependency(%q<websocket>.freeze, [">= 0"])
    s.add_dependency(%q<event_emitter>.freeze, [">= 0"])
  end
end
