module Sidekiq
  class Encryptor

    module Version
      MAJOR = 0
      MINOR = 1
      PATCH = 2
      SUFFIX = ""
    end

    PROTOCOL_VERSION = 1

    VERSION = "#{Version::MAJOR}.#{Version::MINOR}.#{Version::PATCH}#{Version::SUFFIX}"

  end
end
