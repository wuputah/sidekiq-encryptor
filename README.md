# Sidekiq::Encryptor

[![Build Status](https://secure.travis-ci.org/wuputah/sidekiq-encryptor.png)](http://travis-ci.org/wuputah/sidekiq-encryptor)
[![Dependency Status](https://gemnasium.com/wuputah/sidekiq-encryptor.png)](https://gemnasium.com/wuputah/sidekiq-encryptor)

Sidekiq::Encryptor is a middleware set for Sidekiq that encrypts your
job data when enqueuing a job and decrypts that data when running a job.

## Compatibility

Sidekiq::Encryptor is actively tested against MRI versions 2.0.0 and 1.9.3.

## Installation

Add this line to your application's Gemfile:

    gem 'sidekiq-encryptor'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install sidekiq-encryptor

## Configuration

In a Rails initializer or wherever you've configured Sidekiq, add
the relevant Sidekiq::Encryptor middlewares as follows:

```ruby
key = ENV['SIDEKIQ_ENCRYPTION_KEY']

Sidekiq.configure_server do |config|
  config.server_middleware do |chain|
    chain.add Sidekiq::Encryptor::Server, key: key
  end
  config.client_middleware do |chain|
    chain.add Sidekiq::Encryptor::Client, key: key
  end
end

Sidekiq.configure_client do |config|
  config.client_middleware do |chain|
    chain.add Sidekiq::Encryptor::Client, key: key
  end
end
```

You should also set `SIDEKIQ_ENCRYPTION_KEY` to something sufficiently
random. The `openssl` tool is a good choice for this:

  echo SIDEKIQ_ENCRYPTION_KEY=$(openssl rand -base64 48) >>.env
  # if on Heroku...
  heroku config:set SIDEKIQ_ENCRYPTION_KEY=$(openssl rand -base64 48)

## Contributing

Pull requests gladly accepted. Please write tests for any code changes,
though I'll admit my test coverage is completely awful right now.

## License

MIT Licensed. See LICENSE.txt for details.
