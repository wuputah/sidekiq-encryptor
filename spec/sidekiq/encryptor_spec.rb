require 'spec_helper'
require 'securerandom'

[Sidekiq::Encryptor::Client, Sidekiq::Encryptor::Server].each do |klass|

  describe klass do

    raw_key = SecureRandom.random_bytes(32)

    {
      'base64' => [raw_key].pack('m*'),
      'hex' => raw_key.unpack('H*').first,
      'binary' => raw_key
    }.each_pair do |key_type, key|

      describe "with #{key_type} key" do

        subject(:middleware) do
          described_class.new(key: key)
        end

        let(:worker) do
          RegularWorker.new
        end

        let(:data) do
          ['Clint Eastwood']
        end

        let(:args) do
          {
            Sidekiq::Encryptor::Client => data,
            Sidekiq::Encryptor::Server => [
              'Sidekiq::Encryptor',
              1,
              Fernet.generate(Base64.urlsafe_encode64(raw_key), JSON.dump(data))
            ]
          }
        end

        let(:message) do
          { 'args' => args[described_class] }
        end

        let(:queue) do
          'default'
        end

        let(:redis_pool) do
          nil
        end

        it { should be_enabled }

        describe '#call' do

          it 'yields' do
            case described_class
            when Sidekiq::Encryptor::Client
              expect { |b| middleware.call(worker, message, queue, redis_pool, &b) }.to yield_with_no_args
            when Sidekiq::Encryptor::Server
              expect { |b| middleware.call(worker, message, queue, &b) }.to yield_with_no_args
            end
          end
        end
      end
    end
  end

end
