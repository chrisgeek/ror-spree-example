module Spree
  module RabbitMq
    class FullfilledOrder
      def initialize
        @channel = RABBITMQ_CONNECT.create_channel
        # @queue = @channel.queue('fulfilled.orders', durable: true)
        @queue = @channel.queue('orders', durable: true)
      end

      def retrieve_order
        bind_queue
        @queue.subscribe(block: true) do |_delivery_info, _properties, body|
          message = JSON.parse(body)
          order_number = message['number']
          Spree::UpdateOrderStatus.call(order_number, 'send') if order_id
        end
      rescue Interrupt => _e
        @channel.close
      ensure
        RABBITMQ_CONNECT.close
      end

      private

      def bind_queue
        exchange = @channel.headers('syncomm', durable: true)
        @queue.bind(exchange, arguments: { 'object_type' => 'order', 'routing_key' => 'store', 'x-match' => 'all' })
      end
    end
  end
end
