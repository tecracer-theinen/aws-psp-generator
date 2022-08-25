require 'logger' unless defined?(Logger)

module AwsPspGenerator
  module Mixins
    module Logger
      attr_writer :logger

      def logger
        return @logger if @logger

        logger = ::Logger.new($stdout)
        # logger.level = options&.fetch(:verbose, false) ? ::Logger::DEBUG : ::Logger::INFO

        @logger = logger
      end
    end
  end
end
