# coding: utf-8

Gem::Specification.new do |spec|
    spec.name          = "jekyll-builder"
    spec.version       = "0.1.0"
    spec.authors       = ["primate-2016"]
    spec.email         = [""]
  
    spec.summary       = %q{Gems required to bundle with a Lambda function to support building jekyll websites in AWS Lambda}
    spec.homepage      = "http://elasticcows.co.uk"
    spec.license       = "MIT"
  
    spec.files         = `git ls-files -z`.split("\x0").select { |f| f.match(%r{^(_layouts|_includes|_sass|LICENSE|README)/i}) }
  
    spec.add_development_dependency "fileutils"
    spec.add_development_dependency "rubyzip"
    spec.add_development_dependency "zip"
  end
  
