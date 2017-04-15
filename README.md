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

```sh
echo SIDEKIQ_ENCRYPTION_KEY=$(openssl rand -base64 32) >>.env
heroku config:set SIDEKIQ_ENCRYPTION_KEY=$(openssl rand -base64 32)
```

### Advanced Encryption Options

You can encrypt specific worker arguments rather than the entire payload. 
In addition to the `key` option above, you can specify the `encrypt` option for more fine-grained control.

Let's say the worker arguments are as follows:

```ruby
args = [
  # first argument
  123,
  # second argument
  "hello world",
  # third argument
  {
    "transaction" => "TXN0987654",
    "payment" => {
      "card_number" => "4242 4242 4242 4242",
      "expiration" => "2016-01",
      "cvv" => "456"
    }
  },
  # fourth argument
  {
    "user" => {
      "email" => "hello@world.com",
      "password" => "TopSecret!"
    }
  }
]
```

The `encrypt` option can be a boolean that indicates whether encryption is turned on or off. 
Alternatively, you can specify a `Hash` where the keys are the argument index and the values are booleans indicating whether or not the argument will be encrypted:

```ruby
options = {
  key: "0493988a8cf...29e0b4573b",
  encrypt: {
    0 => false,
    # omitting indexes is equivalent to `false`
    2 => true,
    3 => true
  }
}

# encrypted result
result = [
  123,
  "hello world",
  ["Sidekiq::Encryptor", 1, "abc...123=="],
  ["Sidekiq::Encryptor", 1, "def...456=="]
]
```

If an argument is a `Hash`, you may want to encrypt a specific value. 
If the argument happens to be an array of hashes, the property will be encrypted recursively:

```ruby
options = {
  key: "0493988a8cf...29e0b4573b",
  encrypt: {
    0 => false,
    # omitting indexes is equivalent to `false`
    2 => :payment,
    3 => { :user => :password }
  }
}

# encrypted result
result = [
  123,
  "hello world", {
    "transaction" => "TXN0987654",
    "payment" => ["Sidekiq::Encryptor", 1, "abc...123=="]
  }, {
    "user" => {
      "email" => "hello@world.com",
      "password" => ["Sidekiq::Encryptor", 1, "def...456=="]
    }
  }
]
```

If you need to encrypt several attributes, you can list them as arrays, as well as include hashes if necessary. 
Here's an example:

```ruby
options = {
  key: "0493988a8cf...29e0b4573b",
  encrypt: {
    0 => false,
    # omitting indexes is equivalent to `false`
    2 => [:transaction, :payment => [:card_number, :cvv]],
    3 => { :user => :password }
  }
}

# encrypted result
result = [
  123,
  "hello world", {
    "transaction" => ["Sidekiq::Encryptor", 1, "abc...123=="],
    "payment" => {
      "card_number" => ["Sidekiq::Encryptor", 1, "ghi...789=="],
      "expiration" => "2016-01",
      "cvv" => ["Sidekiq::Encryptor", 1, "jkl...098=="]
    }
  }, {
    "user" => {
      "email" => "hello@world.com",
      "password" => ["Sidekiq::Encryptor", 1, "def...456=="]
    }
  }
]
```

Lastly, you can override the middleware `encrypt` option by specifying `encrypt` as a Sidekiq option in your worker class. 
You can set `encrypt` to `false` do disable it, or omit the `encrypt` option from the middleware configuraition and only specify it in your workers:

```ruby
class TopSecretWorker
  include Sidekiq::Worker
  
  sidekiq_options encrypt: {
    1 => { user: :password }
  }
  
  def perform(record_id, user_info)
    # do stuff
  end
end
```

Don't forget to add the `encrypt` option to the Sidekiq "client" and "server" configurations.

## Contributing

Pull requests gladly accepted. Please write tests for any code changes,
though I'll admit my test coverage is completely awful right now.

## License

MIT Licensed. See LICENSE.txt for details.
