module ActiveMerchant
  module Versionable
    def self.included(base)
      if base.respond_to?(:class_attribute)
        base.class_attribute :versions, default: {}
        base.extend(ClassMethods)
      end
    end

    module ClassMethods
      def inherited(subclass)
        super
        subclass.versions = {}
      end

      def version(version, feature = :default_api)
        versions[feature] = version
      end

      def fetch_version(feature = :default_api)
        versions[feature]
      end
    end

    def fetch_version(feature = :default_api)
      versions[feature]
    end
  end
end
