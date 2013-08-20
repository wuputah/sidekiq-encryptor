require 'spec_helper'

[Sidekiq::Encryptor::Client, Sidekiq::Encryptor::Server].each do |klass|

  describe klass do

    subject(:middleware) do
      described_class.new
    end

    let(:worker) do
      RegularWorker.new
    end

    let(:message) do
      {
        args: 'Clint Eastwood'
      }
    end

    let(:queue) do
      'default'
    end

    describe '#call' do

      it 'yields' do
        expect { |b| middleware.call(worker, message, queue, &b) }.to yield_with_no_args
      end
    end
  end

end
