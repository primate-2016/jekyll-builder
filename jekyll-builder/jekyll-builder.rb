require 'json'
require 'aws-sdk'
require 'logger'
require 'fileutils'
require 'zip'
require 'net/http'
require 'open3'
require_relative 's3_folder_upload.rb'

def logger
  logger = Logger.new(STDERR)
  logger.level = Logger::DEBUG
  logger
end

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

  logger.debug { "event received: #{event}" }
  html_url = "#{event['repository']['html_url']}/archive/master.zip"
  logger.debug { "html url of git repo: #{html_url}" }
  
  Open3.capture3("rm -rf /tmp/archive.zip")
  get_url(html_url)
  
  extract_dir = '/tmp/extract_dir/'
  Open3.capture3("rm -rf #{extract_dir}")
  unzip_file('/tmp/archive.zip', extract_dir)
  
  files = Open3.capture3("ls #{extract_dir}/test-jekyll-master/_posts")
  logger.debug { "files = #{files}" }
  
  repo_name = event['repository']['name']
  master_branch = event['repository']['master_branch']

  repo_dir = extract_dir + repo_name + '-' + master_branch
  
  logger.debug { "repo_dir: #{repo_dir}" }
  
  # jekyll build will barf without Git installed, Lambda execution environment does
  # not have git installed, so install it
  git_install = Open3.capture3("rm -fr /tmp/git-2.13.5 && \
                                mkdir /tmp/git-2.13.5 && \
                                cd /tmp/git-2.13.5 && \
                                curl -s -O http://packages.eu-west-1.amazonaws.com/2017.03/updates/ba2b87ec77c7/x86_64/Packages/git-2.13.5-1.53.amzn1.x86_64.rpm && \
                                rpm -K git-2.13.5-1.53.amzn1.x86_64.rpm && \
                                rpm2cpio git-2.13.5-1.53.amzn1.x86_64.rpm | cpio -id && \
                                rm git-2.13.5-1.53.amzn1.x86_64.rpm")
  logger.debug { "git install stage output is: #{git_install}" }

  # need to set all sorts of env vars here to work around restrictions in the underlying
  # Lambda execution environment. Jekyll build will barf without bundler installed, its
  # packaged in the Lambda layer, install it. Jekyll build will also barf if the
  # dir it runs in is not a git repo (!?) so git init the folder. 
  output = Open3.capture3({'HOME' => repo_dir, \
                            'GIT_TEMPLATE_DIR' => '/tmp/git-2.13.5/usr/share/git-core/templates', \
                            'GIT_EXEC_PATH' => '/tmp/git-2.13.5/usr/libexec/git-core' }, \
                            "cd #{repo_dir} && \
                            GEM_HOME=/tmp/ && \
                            GEM_PATH=/opt/ruby/2.5.0/:$GEM_PATH && \
                            GEM_PATH=/tmp/:$GEM_PATH && \
                            PATH=/opt/ruby/2.5.0/bin/:$PATH && \
                            PATH=/tmp/git-2.13.5/usr/bin/:$PATH && \
                            gem install --local /opt/ruby/bundler-2.0.1.gem && \
                            git init && \
                            jekyll build && \
                            ls _site/")
  logger.debug { "Jekyll build stage output is: #{output}" }
  # TODO: the above is not causing the function to fail even if jekyll can't build the website and is returning 1 - need to figure out why

  site_dir = repo_dir + '/_site'
  files = Open3.capture3("ls #{site_dir}")
  logger.debug { "files are #{files}" }
  
  # TODO: need to check there are files in the site_dir or the dir exists, otherwise throw an exception
  uploader = S3FolderUpload.new(site_dir, 'elasticcows.co.uk',  include_folder = false)
  uploader.upload!
  
end

