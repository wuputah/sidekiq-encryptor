require 'sidekiq'
require 'active_support/message_encryptor'
require 'active_support/message_verifier'

require 'sidekiq/encryptor/version'

module Sidekiq
  class Encryptor

    Error = Class.new(::RuntimeError)
    DecryptionError = Class.new(Error)

    class Base
      def initializer(options = {})
        @key = options[:key]
        @encryptor = ActiveSupport::MessageEncryptor.new(@key) if @key
      end
    end

    class Client < Base
      def call(worker, msg, queue)
        return yield unless @key
        yield worker,
          @encryptor.encrypt_and_sign(Sidekiq.dump_json(msg)),
          queue
      end
    end

    class Server < Base
      def call(worker, msg, queue)
        return yield unless @key
        yield worker,
          Sidekiq.load_json(@encryptor.decrypt_and_verify(msg)),
          queue
      rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveSupport::MessageEncryptor::InvalidMessage
        raise DecryptionError, "Unable to decrypt job payload"
      end
    end

  end # Encryptor
end # Sidekiq
