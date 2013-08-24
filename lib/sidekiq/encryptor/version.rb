module Sidekiq
  class Encryptor

    module Version
      MAJOR = 0
      MINOR = 1
      PATCH = 0
      SUFFIX = "pre"
    end

    PROTOCOL_VERSION = 0

    VERSION = "#{Version::MAJOR}.#{Version::MINOR}.#{Version::PATCH}#{Version::SUFFIX}"

  end
end
