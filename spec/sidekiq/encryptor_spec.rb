require 'spec_helper'

describe Sidekiq::Encryptor do

  subject(:throttler) do
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
      expect { |b| throttler.call(worker, message, queue, &b) }.to yield_with_no_args
    end
  end
end
