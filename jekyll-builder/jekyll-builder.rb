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

  logger.debug { "event received: #{event}" }
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

  #output = Open3.capture3({'GEM_HOME' => ENV['GEM_HOME']}, "PATH=/var/runtime/gems/bundler-1.17.1/exe/:$PATH && env && bundle")
  #output = Open3.capture3("gem install bundler")

  git_install = Open3.capture3("rm -fr /tmp/git-2.13.5 && \
                                mkdir /tmp/git-2.13.5 && \
                                cd /tmp/git-2.13.5 && \
                                curl -s -O http://packages.eu-west-1.amazonaws.com/2017.03/updates/ba2b87ec77c7/x86_64/Packages/git-2.13.5-1.53.amzn1.x86_64.rpm && \
                                rpm -K git-2.13.5-1.53.amzn1.x86_64.rpm && \
                                rpm2cpio git-2.13.5-1.53.amzn1.x86_64.rpm | cpio -id && \
                                rm git-2.13.5-1.53.amzn1.x86_64.rpm && \
                                cd /tmp/git-2.13.5 && \
                                HOME=/var/task && \
                                GIT_TEMPLATE_DIR=/tmp/git-2.13.5/usr/share/git-core/templates && \
                                GIT_EXEC_PATH=/tmp/git-2.13.5/usr/libexec/git-core && \
                                /tmp/git-2.13.5/usr/bin/git")
  logger.info { "git is #{git_install}" }
  
  output = Open3.capture3({'HOME' => repo_dir, \
                            'GIT_TEMPLATE_DIR' => '/tmp/git-2.13.5/usr/share/git-core/templates', \
                            'GIT_EXEC_PATH' => '/tmp/git-2.13.5/usr/libexec/git-core' }, \
                            "cd #{repo_dir} && \
                            GEM_HOME=/tmp/ && \
                            GEM_PATH=/opt/ruby/2.5.0/:$GEM_PATH && \
                            GEM_PATH=/tmp/:$GEM_PATH && \
                            PATH=/opt/ruby/2.5.0/bin/:$PATH && \
                            PATH=/tmp/git-2.13.5/usr/bin/:$PATH && \
                            ls /opt/ruby/ && \
                            gem install --local /opt/ruby/bundler-2.0.1.gem && \
                            jekyll build")
  logger.info { "output is: #{output}" }
=begin
  #repo_dir = '/tmp'
  output = Open3.capture3({'HOME' => repo_dir}, \
                            "cd #{repo_dir} && \
                            GEM_HOME=/tmp/ && \
                            GEM_PATH=/opt/ruby/2.5.0/:$GEM_PATH && \
                            GEM_PATH=/tmp/:$GEM_PATH && \
                            PATH=/opt/ruby/2.5.0/bin/:$PATH && \
                            gem install --local /opt/ruby/bundler-2.0.1.gem && \
                            gem env && \
                            jekyll build")
  logger.info { "output is: #{output}" }
=end


end

# install of jekyll is failing - need to figure out how to package this 
# maybe do it like you grabbed the installed bundler the first time?
# - some of the jekyll themes don;t have gemfiles anyway 
# and you just run jekyll build against them - i.e. they expect jekyll to be there
# you were getting confused with what was in the gemfile.lock as a result of running bundle install
# against the gemspec - the gemfile.lock showed all the gems it pulled down
# you might only need jekyll....
