module Spree
  class UpdateOrderStatus
    def self.call(order_number, status)
      order = Spree::Order.find_by(order_number: order_number)
      if order
        order.update(status: status)
        Rails.logger.info "Order ##{order_number} status updated to '#{status}'"
      else
        Rails.logger.warn "Order ##{order_number} not found!"
      end
    end
  end
end
