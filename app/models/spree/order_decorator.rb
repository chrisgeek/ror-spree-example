module Spree
  module OrderDecorator
    def self.prepended(base)
      base.state_machine.after_transition to: :complete, do: :publish_order
      base.include Spree::Core::NumberGenerator.new(prefix: 'RORSEN')
    end

    def publish_order
      Spree::RabbitMq::Producer.publish('orders', attributes, { object_type: 'order', routing_key: 'store' })
    end
  end
  Order.prepend(OrderDecorator)
end
