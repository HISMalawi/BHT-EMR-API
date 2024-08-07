# -*- encoding: utf-8 -*-
# stub: websocket-client-simple 0.3.1 ruby lib

Gem::Specification.new do |s|
  s.name = "websocket-client-simple".freeze
  s.version = "0.3.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "changelog_uri" => "https://github.com/ruby-jp/websocket-client-simple/blob/master/History.txt", "homepage_uri" => "https://github.com/ruby-jp/websocket-client-simple", "source_code_uri" => "https://github.com/ruby-jp/websocket-client-simple" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Sho Hashimoto".freeze, "Yusuke Nakamura".freeze]
  s.date = "2021-12-30"
  s.description = "Simple WebSocket Client for Ruby".freeze
  s.email = ["hashimoto@shokai.org".freeze, "yusuke1994525@gmail.com".freeze]
  s.homepage = "https://github.com/ruby-jp/websocket-client-simple".freeze
  s.licenses = ["MIT".freeze]
  s.post_install_message = "The development of this gem has moved to https://github.com/ruby-jp/websocket-client-simple.".freeze
  s.rubygems_version = "3.4.1".freeze
  s.summary = "Simple WebSocket Client for Ruby".freeze

  s.installed_by_version = "3.4.1" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_development_dependency(%q<bundler>.freeze, [">= 0"])
  s.add_development_dependency(%q<rake>.freeze, [">= 0"])
  s.add_development_dependency(%q<minitest>.freeze, [">= 0"])
  s.add_development_dependency(%q<websocket-eventmachine-server>.freeze, [">= 0"])
  s.add_development_dependency(%q<eventmachine>.freeze, [">= 0"])
  s.add_runtime_dependency(%q<websocket>.freeze, [">= 0"])
  s.add_runtime_dependency(%q<event_emitter>.freeze, [">= 0"])
end
