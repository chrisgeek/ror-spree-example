require 'bunny'

RABBITMQ_CONNECT = Bunny.new(ENV['AMQP_URL'])

RABBITMQ_CONNECT.start
