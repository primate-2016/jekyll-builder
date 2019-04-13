require 'json'
require 'aws-sdk'
require 'logger'
require 'open-uri'
require 'fileutils'

def logger
   logger = Logger.new(STDERR)
   logger.level = Logger::DEBUG
   logger
end

def download(url, path)
  case io = open(url)
  when StringIO then File.open(path, 'w') { |f| f.write(io) }
  when Tempfile then io.close; FileUtils.mv(io.path, path)
  end
end

def lambda_handler(event:, context:)
    # TODO implement
    logger.debug { "event received: #{event}" }
    html_url = "#{event['repository']['html_url']}/archive/master.zip"
    logger.debug { "html url of git repo: #{html_url}" }
    #{ statusCode: 200, body: JSON.generate('Hello from Lambda!') }
    
    download(html_url /tmp/)
    
end