require 'json'
require 'aws-sdk'
require 'logger'

def logger
   logger = Logger.new(STDERR)
   logger.level = Logger::DEBUG
   logger
end

def lambda_handler(event:, context:)
    # TODO implement :)
    logger.debug { "event received: #{event}" }
    { statusCode: 200, body: JSON.generate('Hello from Lambda!') }
end