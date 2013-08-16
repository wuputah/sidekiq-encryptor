require 'sidekiq'
require 'active_support/message_encryptor'
require 'active_support/message_verifier'

require 'sidekiq/encryptor/version'

module Sidekiq
  class Encryptor

    # Passes the worker, arguments, and queue to {RateLimit} and either yields
    # or requeues the job depending on whether the worker is throttled.
    #
    # @param [Sidekiq::Worker] worker
    #   The worker the job belongs to.
    #
    # @param [Hash] msg
    #   The job message.
    #
    # @param [String] queue
    #   The current queue.
    def call(worker, msg, queue)
      yield
    end

  end # Throttler
end # Sidekiq
