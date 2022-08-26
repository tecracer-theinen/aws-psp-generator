module AwsPspGenerator
  class ChefProperty
    attr_reader :description
    attr_accessor :property_name, :api_name, :required, :parent_resource

    def initialize(parent_resource, aws_data)
      @parent_resource = parent_resource

      @aws_data    = aws_data
      @description = aws_data['description']
    end

    def type(named_type = nil)
      aws_type = named_type || @aws_data['type']

      case aws_type
      when 'boolean'
        '[TrueClass, FalseClass]'
      when 'array'
        if @aws_data['type'] == 'array'
          'Array'
        else
          # Allow coercion to specify e.g. single string even if array expected
          aws_subtype = @aws_data.dig('items', 'type')

          # TODO: could be items -> $ref!
          "[#{aws_subtype.capitalize}, Array],\n         coerce: proc { |x| Array(x) }" if aws_subtype.is_a? String
        end
      when 'object', nil
        'Hash'
        # TODO: See AWS::MediaTailor::PlaybackConfiguration
        # "patternProperties"=>{"[a-zA-Z0-9]+"=>{"type"=>"string"}}
        # "patternProperties"=>{".*"=>{"type"=>"string", "maxLength"=>51200}},
      when String
        aws_type.capitalize
      when Array
        converted_types = aws_type.map { |t| type(t) }
        "[#{converted_types.join(', ')}]"
      else
        @description = complex_definition['description'] if complex_definition

        if @aws_data.key? 'oneOf'
          'Hash' # TODO, see AWS::DynamoDB::Table
        else
          type(complex_definition['type'])
        end
      end
    end

    def type_validations
      # Scalar type
      return callbacks(@aws_data) unless type_definition? || type == 'Hash'

      # Lookup $ref or expand Object types
      definitions = complex_definition || @aws_data
      return callbacks(definitions) if definitions['properties'].nil? # Flat definition

      output = ''
      definitions['properties']&.each do |subkey, definition|
        output += callbacks(definition, subkey) || ''
      end

      output
    end

    def type_definition?
      @aws_data['$ref']
    end

    private

    def logger
      Runner.instance.logger
    end

    def complex_definition(name = nil)
      return unless type_definition? || name

      definition = @aws_data.dig('items', '$ref') || @aws_data['$ref'] # ?
      definition&.delete_prefix!('#/definitions/')

      parent_resource.definitions[name || definition]
    end

    def callbacks(definition, subkey = nil)
      return '' if definition.key? '$ref' # TODO: Recurse
      return '' if definition.key? 'oneOf' # TODO, see AWS::DynamoDB::Table
      return '' if definition['type'].is_a?(Array) # TODO: ["string", "object"], but has no validations
      return '' if definition['type'].nil? # TODO, see AWS::MediaTailor::PlaybackConfiguration

      type    = definition['type'].capitalize
      tocheck = subkey ? "v[:#{subkey}]" : 'v'

      # General type check
      output  = subkey ? "\"Subproperty `#{subkey}` " : "\"#{property_name} "
      output += "is not a #{type}\" => lambda { |v| #{tocheck}.is_a? #{type} },\n"

      output += callbacks_integer(definition, subkey) if type == 'Integer'
      output += callbacks_string(definition, subkey)  if type == 'String'

      output
    end

    def callbacks_integer(definition, subkey = nil)
      output  = ''
      prefix  = subkey ? "Subproperty `#{subkey}` " : "#{property_name} "
      tocheck = subkey ? "v[:#{subkey}]" : 'v'

      min = definition['minValue']
      max = definition['maxValue']
      output += "\"#{prefix} needs to be between #{min} and #{max}\" => lambda { |v| #{tocheck} >= #{min} && #{tocheck} <= #{max} },\n" if max && min

      allowed = definition['allowedValues']
      output += "\"#{prefix} is not one of the allowed values\" => lambda { |v| %w[#{allowed_values.join(' ')}].include? #{tocheck} },\n" if allowed

      output
    end

    def callbacks_string(definition, subkey = nil)
      output  = ''
      prefix  = subkey ? "Subproperty `#{subkey}`" : property_name
      tocheck = subkey ? "v[:#{subkey}]" : 'v'

      min = definition['minLength']
      max = definition['maxLength']
      output += "\"#{prefix} needs to be #{min}..#{max} characters\" => lambda { |v| #{tocheck}.length >= #{min} && #{tocheck}.length <= #{max} },\n" if max && min

      pattern = definition['pattern']
      output += "\"#{prefix} must match pattern #{pattern}\" => lambda { |v| #{tocheck} =~ Regexp.new(\"/#{pattern}/\") },\n" if pattern

      allowed = definition['allowedValues']
      output += "\"#{prefix} is not one of the allowed values\" => lambda { |v| %w{#{allowed_values.join(' ')}}.include? #{tocheck} },\n" if allowed

      # ARN
      output += "\"#{prefix}is not a valid ARN\" => lambda { |v| #{tocheck} =~ Regexp.new('#{ARN_PATTERN}') },\n" if subkey&.end_with?('Arn')

      if (enum = definition['enum'])
        output += "\"#{prefix}is not one of `#{enum.join('`, `')}`\" => lambda { |v| %w{#{enum.join(' ')}}.include? #{tocheck} },\n"
      end

      # no validator
      return '' if output[-1] != "\n"

      output
    end
  end
end
