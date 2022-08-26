require_relative 'chef_property'
require_relative 'chef_resource'
require_relative 'mixins/logger'
require_relative 'mixins/utils'

require 'aws-sdk-cloudformation' unless defined?(Aws::CloudFormation)
require 'erubis' unless defined?(Erubis)
require 'fileutils' unless defined?(FileUtils)
require 'singleton' unless defined?(Singleton)

module AwsPspGenerator
  class Runner
    include Singleton
    include AwsPspGenerator::Mixins::Logger
    include AwsPspGenerator::Mixins::Utils

    attr_reader :aws_resource
    attr_writer :cfn

    def list_resources
      available_resources.map(&:type_name)
    end

    # @see https://docs.aws.amazon.com/cloudcontrolapi/latest/userguide/resource-types.html#resource-types-determine-support
    def available_resources
      @available_resources ||= (paged_response('IMMUTABLE') + paged_response('FULLY_MUTABLE')).sort_by(&:type_name).select { |r| r.type_name.start_with? 'AWS::' }
    end

    def last_update(api_name)
      resource_data = available_resources.detect { |type| type.type_name == api_name }
      resource_data&.last_updated&.to_datetime
    end

    def render_resource(resource)
      erb = Erubis::Eruby.new(erb_template)

      erb.result(
        resource: resource
      ).gsub(/ +$/m, '')
    end

    def write_definition(resource)
      FileUtils.mkdir_p(RESOURCES_DIR)

      contents = render_resource(resource)

      resource_file = filename(resource.api_name)
      File.write(resource_file, contents)
    end

    def cfn_typedata(api_name)
      cfn.describe_type(type: 'RESOURCE', type_name: api_name)
    rescue Aws::CloudFormation::Errors::LimitExceededException,
           Aws::CloudFormation::Errors::Throttling
      retry_counter = 0 || (retry_counter + 1)
      raise(Error, "Backoff failed for #{api_name}") if retry_counter > 5

      # Exponential Backoff: 1 -> 2 -> 4 -> 8 -> 16 -> 32 sec
      sleep(2**retry_counter)
      retry
    rescue Aws::CloudFormation::Errors::TypeNotFoundException
      logger.error "Unknown type #{api_name}"
      exit EXIT_USAGE
    end

    def filename(api_name)
      File.join(::AwsPspGenerator::RESOURCES_DIR, "#{chef_resource(api_name)}.rb")
    end

    def chef_resource(api_name)
      chefify api_name.gsub('::', '_')
    end

    private

    def erb_template
      File.read File.join(__dir__, '../../templates', ERB_TEMPLATE)
    end

    def paged_response(provisioning_type)
      results  = []
      response = cfn.list_types(visibility: 'PUBLIC', type: 'RESOURCE', provisioning_type: provisioning_type)

      while response.next_page?
        results.concat response.type_summaries
        response = response.next_page
      end

      results
    end

    def cfn
      check_aws_credentials! unless @cfn

      @cfn ||= Aws::CloudFormation::Client.new
    end

    def check_aws_credentials!
      sts = Aws::STS::Client.new
      ci = sts.get_caller_identity
      logger.info "AWS Account #{ci.account}"
    rescue Aws::Errors::MissingCredentialsError
      logger.error 'No AWS credentials found'
      exit 1
    end
  end
end
