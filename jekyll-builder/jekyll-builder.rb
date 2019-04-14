require 'json'
#require 'aws-sdk'
require 'logger'
#require 'open-uri'
require 'fileutils'
require 'zip'
require 'net/http'
#require 'bundler/setup'
require 'open3'

def logger
  logger = Logger.new(STDERR)
  logger.level = Logger::DEBUG
  logger
end
=begin
def download(url)
  case io = open(url)
  when StringIO then File.open(path, 'w') { |f| f.write(io) }
  when Tempfile then io.close #; FileUtils.mv(io.path, path)
  end
  Tempfile.path
end
=end

def download(url)
  url = URI(url)
  Net::HTTP.start(url.host, url.port, :use_ssl => true) do |http|
    request = Net::HTTP::Get.new url

    http.request request do |response|
      #logger.debug { "response #{response}" }
      open '/tmp/archive.zip', 'w' do |io|
        response.read_body do |chunk|
          # logger.debug { "chunk #{chunk}" }
          io.write chunk
        end
      end
    end
  end
end

def get_url(url, limit = 10)
  logger.error { 'too many HTTP redirects' } if limit == 0
  raise ArgumentError, 'too many HTTP redirects' if limit == 0

  response = Net::HTTP.get_response(URI(url))

  case response
  when Net::HTTPSuccess then
    logger.info { "Downloading zip archive from #{url}" }
    download(url)
  when Net::HTTPRedirection then
    url = response['location']
    logger.warn { "redirected to #{url}" }
    get_url(url, limit - 1)
  else
    logger.error { "Unexpected HTTP return code: #{response.value}" }
    response.value
  end
end

def unzip_file (file, destination)
  logger.info { 'Extracting zip archive' }
  Zip::File.open(file) do |zip_file|
    zip_file.each do |f|
      f_path=File.join(destination, f.name)
        FileUtils.mkdir_p(File.dirname(f_path))
        zip_file.extract(f, f_path) unless File.exist?(f_path)
    end
  end
end

def lambda_handler(event:, context:)
=begin
  #logger.debug { "event received: #{event}" }
  #html_url = 'https://github.com/primate-2016/test-jekyll/archive/master.zip'
  html_url = "#{event['repository']['html_url']}/archive/master.zip"
  logger.debug { "html url of git repo: #{html_url}" }
  #{ statusCode: 200, body: JSON.generate('Hello from Lambda!') }
  
  get_url(html_url)
  
  extract_dir = '/tmp/extract_dir/'
  unzip_file('/tmp/archive.zip', extract_dir)
  
  # need to get name of repo from event
  repo_name = event['repository']['name']
  master_branch = event['repository']['master_branch']
  
  # i'm making an assumption that git will always retirn the master branch when downloadnig from zip endpoint
  # and that the master branch will be whatever is listed in the webhook as master - need to validate
  #master_branch = 'master'
  #repo_name = 'test-jekyll'
  repo_dir = extract_dir + repo_name + '-' + master_branch
  
  logger.debug { "repo_dir: #{repo_dir}" }
  
  # try running bundle at the system level rather than in the jekyll project - this way if gems are already
  # present they wont be downloaded again and lambda execution will be faster
  #output = IO.popen("#{ENV['GEM_PATH']}/bundle --gemfile=#{repo_dir}/Gemfile install")
  #output = IO.popen("env")
  #output = system("cd #{repo_dir} && bundle install")
=end
  #output = Open3.capture3({'GEM_PATH' => ENV['GEM_PATH']}, "PATH=#{ENV['LAMBDA_TASK_ROOT']}/vendor/bundle/ruby/2.5.0:$PATH && bundle")
  output = Open3.capture3("ls /opt/")
  logger.info { "output is: #{output}" }
end