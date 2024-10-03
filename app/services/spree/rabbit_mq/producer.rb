# frozen_string_literal: true

module Spree
  module RabbitMq
    class Producer
      class PublishError < StandardError; end

      MAX_RETRIES = 2 # use two for test purpose
      RETRY_DELAY = 1 # second

      attr_reader :exchange_name, :message, :headers, :queue_name

      def initialize(exchange_name, message, headers = {}, queue_name = 'orders')
        @exchange_name = exchange_name
        @message = message
        @headers = headers
        @queue_name = queue_name
      end

      def self.publish(exchange_name, message, headers = default_header)
        new(exchange_name, message, headers).publish_message
      end

      def publish_message
        retries = 0
        begin
          channel = RABBITMQ_CONNECT.create_channel
          exchange = channel.exchange(exchange_name, type: :headers, durable: true)
          bind_to_queue(channel)
          exchange.publish(
            message.to_json,
            headers: headers,
            persistent: true
          )
        rescue Bunny::Exception, Timeout::Error => e
          retries += 1
          if retries <= MAX_RETRIES
            Rails.logger.warn "RabbitMQ publish attempt #{retries} failed: #{e.message}. Retrying in #{RETRY_DELAY} seconds."
            sleep RETRY_DELAY
            retry
          else
            Rails.logger.error "Failed to publish message after #{MAX_RETRIES} attempts: #{e.message}"
          end
        rescue PublishError => e
          Rails.logger.error "Unexpected error when publishing to RabbitMQ: #{e.message}"
        ensure
          channel&.close
        end
      end

      def default_header
        { object_type: 'order', routing_key: 'store' }
      end

      private

      def bind_to_queue(channel)
        queue = channel.queue(queue_name, durable: true)

        queue.bind(exchange_name, arguments: { 'x-match' => 'all',
                                               'object_type' => headers['object_type'],
                                               'routing_key' => headers['routing_key'] })
      end
    end
  end
end
