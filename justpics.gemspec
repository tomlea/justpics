# coding: utf-8

Gem::Specification.new do |spec|
  spec.add_dependency 'sinatra'
  spec.add_dependency 'aws-sdk'
  spec.authors       = ['Tom Lea']
  spec.description   = %q{Simple image serving. Without trying to be too clever.}
  spec.email         = ['contrib@tomlea.co.uk']
  spec.files         = %w(README.markdown justpics.gemspec)
  spec.files        += Dir.glob("lib/**/*.rb")
  spec.homepage      = 'http://github.com/cwninja/justpics'
  spec.name          = 'justpics'
  spec.require_paths = ['lib']
  spec.summary       = spec.description
  spec.version       = "1.0"
end
