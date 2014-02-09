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

    # The [Base] class provides utilities for both
    # the [Client] and [Server] classes. Options are
    # specified in an initializer or via Sidekiq
    # options in a worker class.
    class Base
      # The constructor accepts options for
      # the middleware, which were specified
      # when the middleware was added to Sidekiq.
      #
      # @example Minimum middleware configuration:
      #
      #   options = {
      #     key: "0493988a8cfdb29e0b4573b"
      #   }
      #
      # @note If an encryption key is specified
      #   without the [:encrypt] option, encryption
      #   is enabled (for backwards-compatability)
      #
      # @example Specify which arguments to encrypt
      #   by creating a [Hash] where each key
      #   corresponds to an argument index. The value
      #   can be a single [Hash] key, an array of keys,
      #   a [Hash] that specifies a path into a nested
      #   object, or any combination thereof. If you
      #   want the whole argument encrypted, set the
      #   option to `true`.
      #
      #   @note The way [Hash] keys are specified for
      #     encryption is meant to be similar to how
      #     Rails allows you to serialize JSON.
      #
      #   options = {
      #     key: "0493988a8cfdb29e0b4573b",
      #     encrypt: {
      #       # encrypt the 1st arg
      #       0 => true,
      #
      #       # encrypt the "password" on the 2nd arg
      #       1 => :password,
      #
      #       # encrypt 3 properties on the 3rd arg
      #       2 => [
      #         :card_number,
      #         :expiration_date,
      #         :cvv
      #       ],
      #
      #       # encrypt a property and some nested ones
      #       3 => {
      #         :card => [:number, :exp_date]
      #       },
      #
      #       # encrypt multiple properties and nested
      #       4 => [
      #         :password, {
      #           :card => [:number, :cvv]
      #         }
      #       ]
      #     }
      #   }
      #
      # @param options [Hash]
      # @option options [String] :key The encryption
      #   key to use (required)
      # @option options [Boolean,Hash] :encrypt
      #   Specifies whether encryption is enabled
      #   for the entire payload or only for specific
      #   values within the payload (optional)
      def initialize(options = {})
        @options = options.dup
        @key = validate_key(compact_key(options[:key]))
        @adapter = options[:adapter] || FernetAdapter
      end

      def inspect
        "#<#{self.class.inspect}> @key=[masked] @adapter=#{@adapter.inspect}>"
      end
      alias to_s inspect

      def enabled?(worker_class = nil)
        options = encryption_options(worker_class)
        options[:encrypt] != false
      end
      
      # Get encryption options from middleware config
      # and Sidekiq options in the worker class.
      #
      # @note 
      #
      # @param worker_class [Sidekiq::Worker]
      # @return [Hash] Returns 
      def encryption_options(worker_class = nil)
        @options.dup.tap do |options|
          unless worker_class.nil?
            sidekiq_options = worker_class.get_sidekiq_options
            
            if sidekiq_options.has_key?('encrypt')
              options[:encrypt] = sidekiq_options['encrypt']
            end
          end
          
          # disable encryption if there is no encryption key
          if @key.nil?
            options[:encrypt] = false
          elsif !options.has_key?(:encrypt)
            options[:encrypt] = true
          end
        end
      end

    protected
    
      def encrypted?(input)
        input.is_a?(Array) && input.size == 3 && input.first == 'Sidekiq::Encryptor'
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
          $stderr.puts '[sidekiq-encryptor] ERROR: no key provided, encryption disabled'
        elsif key.bytesize < 32
          $stderr.puts '[sidekiq-encryptor] ERROR: key length less than 256 bits, encryption disabled'
        else
          key.bytes.to_a[0,32].pack('C*')
        end
      end

    end

    class Client < Base
      def call(worker_class, msg, queue, redis_pool = nil)
        worker_class = Kernel.const_get(worker_class) if worker_class.is_a?(String)
        msg['args'] = payload(msg['args'], worker_class)
        yield
      end
    
    private
      
      # Encrypts Sidekiq worker args based on the
      # encryption options specified in a worker
      # class.
      #
      # @see [Base] for encryption option examples
      #
      # @param args [Array] List of args passed
      #   to the worker
      # @param worker_class [Sidekiq::Worker]
      #   The worker class to get Sidekiq options
      #   from
      # @return [Array] Returns a list of args
      #   encrypted based on the options.
      def payload(args, worker_class = nil)
        return args unless enabled?(worker_class)
        
        attributes = encryption_options(worker_class)[:encrypt]
        
        return build_encrypted_value(args) unless attributes.is_a?(Hash)
        
        args.dup.tap do |result|
          attributes.each do |index, attribute|
            if index < args.size
              result[index] = encrypt_nested(args[index], attribute)
            end
          end
        end
      end
      
      # Encrypts Sidekiq worker args based on the
      # encryption options passed in. If the options
      # specify attribute names, the values will be
      # found and encrypted recursively.
      #
      # @see [Base] for encryption option examples
      #
      # @param arg [Object] A worker arg to encrypt
      #   according to encryption options
      # @param attributes [Boolean,Symbol,Hash,Array]
      #   A [Boolean] indicates that the arg shold
      #   be encrypted, while an attribute name (or
      #   names) will cause a recursive lookup
      # @return [Object] Returns a worker arg or
      #   an encrypted version of the arg
      def encrypt_nested(arg, attributes = [])
        return arg if attributes === false || encrypted?(arg)
        return build_encrypted_value(arg) if attributes === true || Array(attributes).empty?
        return arg.map{|item| encrypt_nested(item, attributes)} if arg.is_a?(Array)
        return build_encrypted_value(arg) unless arg.is_a?(Hash)
        
        [attributes].flatten.uniq.each do |attribute|
          # create [Hash] to DRY up code
          attribute = { attribute => [] } unless attribute.is_a?(Hash)
          
          attribute.each do |name, value|
            key = name.to_s
            
            if arg.has_key?(key)
              arg[key] = encrypt_nested(arg[key], value)
            end
          end
        end
        
        arg
      end
      
      # Builds an encrypted representation of
      # the value that should be encrypted.
      #
      # @param input [Object] A worker arg or
      #   nested value in an arg
      # @return [Array] Returns an array with
      #   values representing the encrypted data
      def build_encrypted_value(input)
        [
          'Sidekiq::Encryptor',
          Sidekiq::Encryptor::PROTOCOL_VERSION,
          encrypt(input)
        ]
      end

      # Encrypts a value by first converting to JSON
      # and then encrypting.
      #
      # @note The value is wrapped in an [Array]
      #   before converting to JSON because the
      #   JSON generator requires an [Array] or
      #   [Hash] for conversion
      #
      # @param input [Object] The value to encrypt
      # @return [String] Returns an encrypted value
      def encrypt(input)
        @adapter.encrypt(@key, Sidekiq.dump_json(['Sidekiq::Encryptor::Wrapper', input]))
      end

    end

    class Server < Base
      def call(worker, msg, queue)
        msg['args'] = validate_and_decrypt(msg['args'], worker.class)
        yield
      end

    private

      def validate_and_decrypt(args, worker_class = nil)
        return args unless enabled?(worker_class)
        
        args.map{|arg| decrypt_nested(arg)}
      end
      
      # Decrypts a value.
      #
      # @note The value is wrapped in an [Array]
      #   when initially encrypted to avoid JSON
      #   errors. The value is then returned
      #   without the [Array] wrapper.
      #
      # @param input [Object] The value to decrypt
      #   or traverse to find encrypted values that
      #   need to be decrypted
      # @return [Object] Returns a decrypted value
      def decrypt_nested(arg)
        if encrypted?(arg)
          if version_changed?(arg)
            raise VersionChangeError, 'incompatible change detected'
          else
            data = decrypt(arg) or
              raise DecryptionError, 'key not identical or data was corrupted'
            Sidekiq.load_json(data)
          end
        elsif arg.is_a?(Array)
          arg.map{|item| decrypt_nested(item)}
        elsif arg.is_a?(Hash)
          arg.each_with_object({}) do |(name, value), result|
            result[name] = decrypt_nested(value)
          end
        else
          arg
        end
      end
      
      def version_changed?(input)
        input[1] != Sidekiq::Encryptor::PROTOCOL_VERSION
      end

      def decrypt(input)
        decrypted = @adapter.decrypt(@key, input[2])
        
        if decrypted.is_a?(Array) && decrypted.size == 2 && decrypted.first == 'Sidekiq::Encryptor::Wrapper'
          decrypted.last
        else
          decrypted
        end
      end

    end

  end # Encryptor
end # Sidekiq
