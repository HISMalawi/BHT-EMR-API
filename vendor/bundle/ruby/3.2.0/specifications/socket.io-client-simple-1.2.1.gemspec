# -*- encoding: utf-8 -*-
# stub: socket.io-client-simple 1.2.1 ruby lib

Gem::Specification.new do |s|
  s.name = "socket.io-client-simple".freeze
  s.version = "1.2.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Sho Hashimoto".freeze]
  s.date = "2016-02-20"
  s.description = "A simple ruby client for Node.js's Socket.IO v1.1.x, Supports only WebSocket.".freeze
  s.email = ["hashimoto@shokai.org".freeze]
  s.homepage = "https://github.com/shokai/ruby-socket.io-client-simple".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.4.1".freeze
  s.summary = "A simple ruby client for Node.js's Socket.IO v1.1.x, Supports only WebSocket.".freeze

  s.installed_by_version = "3.4.1" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_development_dependency(%q<bundler>.freeze, ["~> 1.3"])
  s.add_development_dependency(%q<rake>.freeze, [">= 0"])
  s.add_development_dependency(%q<minitest>.freeze, [">= 0"])
  s.add_runtime_dependency(%q<json>.freeze, [">= 0"])
  s.add_runtime_dependency(%q<websocket-client-simple>.freeze, ["~> 0.3.0"])
  s.add_runtime_dependency(%q<httparty>.freeze, [">= 0"])
  s.add_runtime_dependency(%q<event_emitter>.freeze, [">= 0"])
end
