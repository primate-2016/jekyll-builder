require 'json'
require 'aws-sdk'
require 'logger'
#require 'open-uri'
#require 'fileutils'
require 'zip'
require 'net/http'

def logger
  logger = Logger.new(STDERR)
  logger.level = Logger::DEBUG
  logger
end

def download(url)
  case io = open(url)
  when StringIO then File.open(path, 'w') { |f| f.write(io) }
  when Tempfile then io.close #; FileUtils.mv(io.path, path)
  end
  io.path
end

def extract(path)
  Zip::File.open(path) do |zip_file|
    # Handle entries one by one
    zip_file.each do |entry|
      # Extract to file/directory/symlink
      puts "Extracting #{entry.name}"
      entry.extract(dest_file)
    end
  end
end

def lambda_handler(event:, context:)
  # TODO implement
  logger.debug { "event received: #{event}" }
  html_url = "#{event['repository']['html_url']}/archive/master.zip"
  logger.debug { "html url of git repo: #{html_url}" }
  #{ statusCode: 200, body: JSON.generate('Hello from Lambda!') }
  
  path = download(html_url)
  file = "#{path}/master.zip"
  extract(file)
    
end