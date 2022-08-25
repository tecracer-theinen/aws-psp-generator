module AwsPspGenerator
  ERB_TEMPLATE = 'resource.erb'.freeze

  ARN_PATTERN = '^arn:aws(?:-cn|-us-gov)?:([^:]*:){3,}'.freeze

  BACKOFF_INITIAL = 0.5
  BACKOFF_LIMIT   = 120

  RESOURCES_DIR = 'resources/'.freeze
end
