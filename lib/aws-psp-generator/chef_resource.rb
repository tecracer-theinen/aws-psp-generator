require_relative 'chef_property'
require_relative 'constants'
require_relative 'errors'
require_relative 'mixins/utils'

require 'json' unless defined?(JSON)

module AwsPspGenerator
  class ChefResource
    attr_reader :description, :schema, :api_name

    include AwsPspGenerator::Mixins::Utils

    def process(raw)
      @schema = JSON.parse(raw.schema).freeze

      @description = @schema['description']
      @api_name    = @schema['typeName']
      raise(Error, 'API Name needs to start with `AWS::`') unless api_name.start_with? 'AWS::'

      @backoff_timer = BACKOFF_INITIAL
    rescue Aws::CloudFormation::Errors::Throttling
      @backoff_timer ||= BACKOFF_INITIAL
      @backoff_timer *= 2

      if @backoff_timer > BACKOFF_LIMIT
        logger.error 'ERROR: Exponential backoff limit exceeded, retry later or request quota increase'
        exit 100
      end

      logger.warn format('CloudFormation Throttling exception (waiting %d seconds)', @backoff_timer)
      sleep(@backoff_timer)

      retry
    end

    def logger
      runner.logger
    end

    def runner
      Runner.instance
    end

    def chef_name
      chefify @schema['typeName'].gsub('::', '_')
    end

    def name_property
      chefify @schema['primaryIdentifier']
    end

    def generated_identity?
      # Empty intersection = Given name. Non-Empty = Generated
      !!(identity_properties || readonly_properties)
    end

    def arity
      identity_properties.count
    end

    def identity_properties
      api_names = @schema['primaryIdentifier']&.map { |property| property.delete_prefix('/properties/') }

      properties = api_names&.map { |api_name| chefify(api_name) } || []
      properties.sort
    end

    def readonly_properties
      api_names = @schema['readOnlyProperties']&.map { |property| property.delete_prefix('/properties/') }

      properties = api_names&.map { |api_name| chefify(api_name) } || []
      properties.sort
    end

    def post_only_properties
      api_names = @schema['createOnlyProperties']&.map { |property| property.delete_prefix('/properties/') }

      properties = api_names&.map { |api_name| chefify(api_name) } || []
      properties.sort
    end

    def post_only_properties?
      !post_only_properties.empty?
    end

    def required_properties
      api_names = @schema['required']&.map { |property| property.delete_prefix('/properties/') }

      properties = api_names&.map { |api_name| chefify(api_name) } || []
      properties.sort
    end

    def properties
      configurable = @schema['properties'].reject do |api_name, _|
        readonly_properties.include? chefify(api_name)
      end

      properties = configurable&.map { |api_name, data| property_from_data(api_name, data) } || [] # !
      properties.sort_by(&:property_name)
    end

    def property(chef_name)
      properties.detect { |property| property.property_name == chef_name }
    end

    def definitions
      @schema['definitions']
    end

    def mapping
      result = {}

      properties.each { |property| result[property.property_name] = property.api_name }

      result
    end

    private

    def property_from_data(api_name, data)
      property = ChefProperty.new(self, data)

      property.property_name = chefify(api_name)
      property.api_name      = api_name
      property.required      = required_properties.include?(chefify(api_name))

      property
    end
  end
end
