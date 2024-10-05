require 'rails_helper'

RSpec.describe Spree::Order, type: :model do
  describe 'order number generation' do
    it 'generates an order number with prefix "RORSEN"' do
      order = Spree::Order.new
      order.save

      expect(order.number).to start_with('RORSEN')
    end
  end
end
