lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift lib unless $LOAD_PATH.include?(lib)
require 'aws-psp-generator/version'

Gem::Specification.new do |spec|
  spec.name          = 'aws-psp-generator'
  spec.version       = AwsPspGenerator::VERSION
  spec.license       = 'Nonstandard'
  spec.authors       = ['Thomas Heinen']
  spec.email         = ['theinen@tecracer.de']

  spec.summary       = 'Automatically generate Chef AWS resources'
  spec.description   = 'Uses CloudControl API, CloudFormation and Chef REST support'
  spec.homepage      = 'https://tecracer.de'

  spec.files         = Dir['lib/**/**/**']
  spec.files        += Dir['templates/**/**/**']
  spec.files        += Dir['bin/**/*']
  spec.files        += ['README.md', 'CHANGELOG.md']

  spec.bindir        = 'bin'
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 3.0'

  spec.metadata = {
    'rubygems_mfa_required' => 'true'
  }

  spec.add_dependency 'aws-sdk-cloudformation', '~> 1.70'
  spec.add_dependency 'bump', '~> 0.10'
  spec.add_dependency 'erubis', '~> 2.7'
  spec.add_dependency 'fylla', '~> 0.5'
  spec.add_dependency 'thor', '~> 1.0'

  spec.add_development_dependency 'pry', '~> 0.14'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rubocop', '~> 1.35'
end
