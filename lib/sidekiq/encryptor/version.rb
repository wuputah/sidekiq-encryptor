module Sidekiq
  class Encryptor

    module Version
      MAJOR = 0
      MINOR = 1
      PATCH = 1
      SUFFIX = "pre"
    end

    PROTOCOL_VERSION = 1

    VERSION = "#{Version::MAJOR}.#{Version::MINOR}.#{Version::PATCH}#{Version::SUFFIX}"

  end
end
