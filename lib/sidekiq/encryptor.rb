require 'sidekiq'
require 'active_support/message_encryptor'
require 'active_support/message_verifier'

require 'sidekiq/encryptor/version'

module Sidekiq
  class Encryptor

    Error = Class.new(::RuntimeError)
    DecryptionError = Class.new(Error)
    VersionChangeError = Class.new(DecryptionError)

    class Base
      def initialize(options = {})
        @key = options[:key]
        @encryptor = ActiveSupport::MessageEncryptor.new(@key) if @key
      end
    end

    class Client < Base
      def call(worker, msg, queue)
        return yield unless @key
        msg['args'] = ['Sidekiq::Encryptor', Sidekiq::Encryptor::Version::MAJOR, @encryptor.encrypt_and_sign(Sidekiq.dump_json(msg['args']))]
        yield
      end
    end

    class Server < Base
      def call(worker, msg, queue)
        return yield unless @key
        if msg['args'][0] == 'Sidekiq::Encryptor'
          if msg['args'][1] != Sidekiq::Encryptor::PROTOCOL_VERSION
            raise VersionChangeError, 'incompatible change detected'
          else
            msg['args'] = Sidekiq.load_json(@encryptor.decrypt_and_verify(msg['args'][2]))
          end
        end
        yield
      rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveSupport::MessageEncryptor::InvalidMessage
        raise DecryptionError, 'key not identical or data was corrupted'
      end
    end

  end # Encryptor
end # Sidekiq
