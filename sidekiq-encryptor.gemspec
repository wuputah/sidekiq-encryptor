# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'sidekiq/encryptor/version'

Gem::Specification.new do |gem|
  gem.name          = 'sidekiq-encryptor'
  gem.version       = Sidekiq::Encryptor::VERSION
  gem.authors       = ['Jonathan Dance']
  gem.email         = ['rubygems@wuputah.com']
  gem.description   = %q{Sidekiq middleware that encrypts your job data into and out of Redis.}
  gem.summary       = %q{Sidekiq::Encryptor is a middleware for Sidekiq that keeps your information safe by using 2-way encryption when storing and retrieving jobs from Redis.}
  gem.homepage      = 'https://github.com/wuputah/sidekiq-encryptor'
  gem.license       = 'MIT'

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ['lib']

  gem.add_dependency 'fernet', '>= 2.0rc1'
  gem.add_dependency 'sidekiq', '>= 2.5', '< 3.0'

  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'pry'
  gem.add_development_dependency 'yard'
  gem.add_development_dependency 'redcarpet'

  gem.add_development_dependency 'rspec'
  gem.add_development_dependency 'rspec-redis_helper'
  gem.add_development_dependency 'timecop'
  gem.add_development_dependency 'simplecov'

  gem.add_development_dependency 'guard'
  gem.add_development_dependency 'guard-bundler'
  gem.add_development_dependency 'guard-rspec'
  gem.add_development_dependency 'guard-yard'
  gem.add_development_dependency 'rb-fsevent'
  gem.add_development_dependency 'rb-inotify'
  gem.add_development_dependency 'growl'
end
