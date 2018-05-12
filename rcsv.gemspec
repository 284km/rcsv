# -*- encoding: utf-8 -*-
require File.expand_path('../lib/rcsv/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Arthur Pirogovski"]
  gem.email         = ["arthur@flyingtealeaf.com"]
  gem.description   = %q{A libcsv-based CSV parser for Ruby}
  gem.summary       = %q{Fast CSV parsing library for MRI based on libcsv. Supports type conversion, non-strict parsing and basic filtering.}
  gem.homepage      = "http://github.com/fiksu/rcsv"

  gem.files         = `git ls-files`.split($\)
  gem.platform      = Gem::Platform::RUBY
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.extensions    = 'ext/rcsv/extconf.rb'
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "rcsv"
  gem.require_paths = ["lib", "ext"]
  gem.version       = Rcsv::VERSION
  if RUBY_VERSION >= '2.2'
    gem.add_development_dependency "test-unit", "~> 3.0.8"
  end
  gem.add_development_dependency "benchmark-ips"
end
