require_relative '../aws-psp-generator'

require 'date'
require 'fylla' unless defined?(Fylla)
require 'thor' unless defined?(Thor)

module AwsPspGenerator
  class CLI < Thor
    include Thor::Actions
    check_unknown_options!

    def self.exit_on_failure?
      true
    end

    map %w[version] => :__print_version
    desc 'version', 'Display version'
    option :raw, desc: 'Version only', type: :boolean, default: false
    option :json, desc: 'JSON output', type: :boolean, default: false
    def __print_version
      if options[:json]
        say <<~JSON
          {
            "version": "#{AwsPspGenerator::VERSION}",
            "ruby_version": "#{RUBY_VERSION}",
            "platform": "#{RUBY_PLATFORM}"
          }
        JSON
      elsif options[:raw]
        say AwsPspGenerator::VERSION
      else
        say "AWS PSP Generator #{AwsPspGenerator::VERSION} (Ruby #{RUBY_VERSION}-#{RUBY_PLATFORM})"
      end
    end

    no_commands do
      def render_resources
        resources = runner.available_resources

        resources.select! { |resource| updated?(resource.type_name) } unless options[:newer_than].empty?
        resources.reject! { |resource| exist?(resource.type_name) } if options[:skip_existing]

        resources
      end

      def updated?(api_name)
        return true unless options[:newer_than]

        short_timestamp = options[:newer_than].split('.').first
        no_earlier_than = DateTime.strptime(short_timestamp, '%Y-%m-%dT%H:%M:%S')

        no_earlier_than && runner.last_update(api_name) >= no_earlier_than
      rescue Date::Error
        puts 'Option --newer-than must match pattern `%Y-%m-%dT%H:%M:%S`'
        exit EXIT_USAGE
      end

      def exist?(api_name)
        resource_file = runner.filename(api_name)

        File.exist?(resource_file)
      end

      def changed?(api_name)
        return true unless File.exist? runner.filename(api_name)

        chef_resource = ChefResource.new
        chef_resource.process runner.cfn_typedata(api_name)

        new_contents = runner.render_resource(chef_resource)
        old_contents = File.read runner.filename(api_name)

        old_contents != new_contents
      end

      def check_cookbook_directory!
        return if cookbook_directory?

        say 'Must execute in a cookbook directory (i.e. metadata.rb must exist)'
        exit EXIT_USAGE
      end

      def check_aws_type!(name)
        valid = name =~ /^AWS::[A-Za-z0-9]+::[A-Za-z0-9]+$/

        unless valid
          say "Invalid type name #{name}"
          exit EXIT_USAGE
        end
      end

      def cookbook_directory?
        File.exist? 'metadata.rb'
      end

      def root_instance
        ObjectSpace.each_object(AwsPspGenerator::CLI).first
      end

      def runner
        Runner.instance
      end
    end

    # class_option :verbose, desc: 'Run verbosely', type: :boolean
    # class_option :debug,   desc: 'Run in debug mode', type: :boolean

    desc 'auto-complete', 'Generate auto completion code for Bash'
    def auto_complete
      Fylla.load('aws-psp-generator')

      print Fylla.bash_completion(root_instance)
    end

    desc 'list-resources', 'List AWS provided resources from Cloud Control API'
    def list_resources
      say runner.list_resources.join("\n")
    end

    desc 'render RESOURCE', 'Output code for a specific AWS resource'
    def render(api_name)
      check_aws_type!(api_name)

      chef_resource = ChefResource.new
      chef_resource.process runner.cfn_typedata(api_name)

      say runner.render_resource(chef_resource)
    end

    desc 'generate RESOURCE [RESOURCE2] [...]', 'Generate resource DSL for given AWS resource types'
    def generate(*api_names)
      api_names.each { |api_name| check_aws_type!(api_name) }
      check_cookbook_directory!

      api_names.each do |api_name|
        chef_resource = ChefResource.new
        chef_resource.process runner.cfn_typedata(api_name)

        if exist?(api_name)
          say "- Update #{chef_resource}"
        else
          say "- Add #{chef_resource}"
        end

        runner.write_definition(chef_resource)
      end
    end

    desc 'changelog', 'Generate changelog output'
    method_option :newer_than, desc: 'Only resources changed after date', type: :string, default: ''
    def changelog
      render_resources.each do |aws_resource_data|
        api_name = aws_resource_data.type_name
        chef_resource = runner.chef_resource(api_name)

        next unless changed?(api_name)

        if exist?(api_name)
          say "- Update #{api_name}"
        else
          say "- Add #{api_name}"
        end
      end
    end

    desc 'generate-all', 'Generate resource DSL for all AWS resource types'
    method_option :skip_existing, desc: 'Skip existing resources', type: :boolean, default: false
    method_option :newer_than, desc: 'Only resources changed after date', type: :string, default: ''
    def generate_all
      check_cookbook_directory!

      render_resources.each do |aws_resource_data|
        api_name = aws_resource_data.type_name
        say "- #{api_name}"

        chef_resource = ChefResource.new
        chef_resource.process runner.cfn_typedata(api_name)

        runner.write_definition(chef_resource)
      end
    end
  end
end
