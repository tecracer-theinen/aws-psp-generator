module AwsPspGenerator
  module Mixins
    module Utils
      SERVICENAMES = %w[
        ApiGateway AppFlow AppStream AppSync AuditManager AutoScaling CloudFormation CloudTrail
        CloudWatch CodeArtifact CodeGuru CodeStar DataBrew DataSync DynamoDB DevOpsGuru
        ElastiCache ElasticLoadBalancer GameLift GroundStation ImageBuilder
        IoT SiteWise TwinMaker LakeFormation LicenseManager MediaConnect
        MediaPackage MediaTailor MemoryDB NetworkFirewall NetworkInsights NetworkManager
        QuickSight ResilienceHub RoboMaker SageMaker ServiceCatalog StepFunctions
        TransitGateway WAFv2 XRay
      ].freeze

      def chefify(api_name)
        return snake_case(api_name) unless SERVICENAMES.any? { |partial| api_name.include? partial }

        name = api_name.dup

        SERVICENAMES.each do |partial|
          name.sub!(partial, partial.downcase.capitalize)
        end

        snake_case(name)
      end

      def snake_case(string, sep = '_')
        return '' if string.nil?

        string.gsub(/::/, sep)
              .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
              .gsub(/([a-z\d])([A-Z])/, '\1_\2')
              .tr('-', '_')
              .downcase
      end
    end
  end
end
