# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RabbitMq::Producer do
  let(:exchange_name) { 'test_exchange' }
  let(:message) { { order_id: 123, status: 'created' } }
  let(:headers) { { 'object_type' => 'order', 'routing_key' => 'store' } }
  let(:queue_name) { 'orders' }
  let(:channel_double) { instance_double(Bunny::Channel, open?: true) }
  let(:exchange_double) { instance_double(Bunny::Exchange) }
  let(:queue_double) { instance_double(Bunny::Queue) }

  before do
    allow(RABBITMQ_CONNECT).to receive(:create_channel).and_return(channel_double)
    allow(channel_double).to receive(:exchange).and_return(exchange_double)
    allow(channel_double).to receive(:queue).and_return(queue_double)
    allow(channel_double).to receive(:close)
    allow(exchange_double).to receive(:publish)
    allow(queue_double).to receive(:bind)
  end

  describe '.publish' do
    it 'creates a new instance and calls publish_message' do
      instance = instance_double(described_class)
      expect(described_class).to receive(:new).with(exchange_name, message, headers).and_return(instance)
      expect(instance).to receive(:publish_message)
      described_class.publish(exchange_name, message, headers)
    end
  end

  describe '#publish_message' do
    let(:producer) { described_class.new(exchange_name, message, headers) }

    context 'when publishing succeeds' do
      it 'publishes the message with the correct parameters' do
        expect(channel_double).to receive(:exchange).with(exchange_name, type: :headers, durable: true)
        expect(queue_double).to receive(:bind).with(exchange_name, arguments: { 'x-match' => 'all', 'object_type' => 'order', 'routing_key' => 'store' })
        expect(exchange_double).to receive(:publish).with(
          message.to_json,
          headers: headers,
          persistent: true
        )
        producer.publish_message
      end

      it 'closes the channel after publishing' do
        expect(channel_double).to receive(:close)
        producer.publish_message
      end
    end

    context 'when Bunny::Exception or Timeout::Error occurs' do
      before do
        allow(channel_double).to receive(:exchange).and_raise(Bunny::Exception)
        allow(Rails.logger).to receive(:warn)
        allow(Rails.logger).to receive(:error)
      end

      it 'retries up to MAX_RETRIES times' do
        expect(Rails.logger).to receive(:warn).exactly(described_class::MAX_RETRIES).times
        expect(Rails.logger).to receive(:error).once.with(/Failed to publish message after #{described_class::MAX_RETRIES} attempts/)
        producer.publish_message
      end
    end

    context 'when PublishError occurs' do
      before do
        allow(channel_double).to receive(:exchange).and_raise(described_class::PublishError)
        allow(Rails.logger).to receive(:error)
      end

      it 'logs the error and does not retry' do
        expect(Rails.logger).to receive(:error).with(/Unexpected error when publishing to RabbitMQ/).once
        producer.publish_message
      end
    end
  end

  describe '#initialize' do
    it 'sets the instance variables correctly' do
      producer = described_class.new(exchange_name, message, headers, queue_name)
      expect(producer.exchange_name).to eq(exchange_name)
      expect(producer.message).to eq(message)
      expect(producer.headers).to eq(headers)
      expect(producer.queue_name).to eq(queue_name)
    end

    it 'uses default queue_name if not provided' do
      producer = described_class.new(exchange_name, message, headers)
      expect(producer.queue_name).to eq('orders')
    end
  end

  describe '.default_header' do
    it 'returns the correct default header' do
      expect(described_class.new(exchange_name, message).send(:default_header)).to eq(
        { object_type: 'order', routing_key: 'store' }
      )
    end
  end
end
