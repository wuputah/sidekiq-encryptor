# gems
require 'sidekiq'
require 'fernet'

# local files
require 'sidekiq/encryptor/version'

module Sidekiq
  class Encryptor

    Error = Class.new(::RuntimeError)
    DecryptionError = Class.new(Error)
    VersionChangeError = Class.new(DecryptionError)

    module FernetAdapter
      def self.encrypt(key, data)
        Fernet.generate(key, data)
      end

      def self.decrypt(key, data)
        verifier = Fernet::Verifier.new(
          token: data,
          secret: key,
          enforce_ttl: false)
        verifier.valid? ? verifier.message : nil
      rescue OpenSSL::Cipher::CipherError
        nil
      end
    end

    class Base
      def initialize(options = {})
        @silent = options[:silent] || false
        @key = validate_key(compact_key(options[:key]))
        @adapter = options[:adapter] || FernetAdapter
      end

      def inspect
        "#<#{self.class.inspect}> @key=[masked] @adapter=#{@adapter.inspect}>"
      end
      alias to_s inspect

      def enabled?
        !@key.nil?
      end

    private

      def compact_key(key)
        flat_key = key.to_s.delete("\r\n")
        case flat_key
        # empty
        when ""
          nil
        # hexadecimal
        when /^[\da-f]+$/i
          [flat_key].pack('H*')
        # base64
        when /^[A-Za-z\d\+\/=]+$/
          key.unpack('m*').first
        # assume binary otherwise
        else
          key
        end
      end

      def validate_key(key)
        if key.nil?
          $stderr.puts '[sidekiq-encryptor] ERROR: no key provided, encryption disabled' unless @silent
        elsif key.bytesize < 32
          $stderr.puts '[sidekiq-encryptor] ERROR: key length less than 256 bits, encryption disabled' unless @slient
        else
          key.bytes.to_a[0,32].pack('C*')
        end
      end

    end

    class Client < Base
      def call(worker, msg, queue, redis_pool)
        return yield unless enabled?
        msg['args'] = payload(msg['args'])
        yield
      end

    private

      def payload(input)
        [
          'Sidekiq::Encryptor',
          Sidekiq::Encryptor::PROTOCOL_VERSION,
          encrypt(input)
        ]
      end

      def encrypt(input)
        @adapter.encrypt(@key, Sidekiq.dump_json(input))
      end

    end

    class Server < Base
      def call(worker, msg, queue)
        return yield unless enabled?
        msg['args'] = validate_and_decrypt(msg['args'])
        yield
      end

    private

      def validate_and_decrypt(payload)
        if encrypted?(payload)
          if version_changed?(payload)
            raise VersionChangeError, 'incompatible change detected'
          else
            data = decrypt(payload) or
              raise DecryptionError, 'key not identical or data was corrupted'
            Sidekiq.load_json(data)
          end
        else
          payload
        end
      end

      def encrypted?(input)
        input.is_a?(Array) && input.size == 3 && input.first == 'Sidekiq::Encryptor'
      end

      def version_changed?(input)
        input[1] != Sidekiq::Encryptor::PROTOCOL_VERSION
      end

      def decrypt(input)
        @adapter.decrypt(@key, input[2])
      end

    end

  end # Encryptor
end # Sidekiq
