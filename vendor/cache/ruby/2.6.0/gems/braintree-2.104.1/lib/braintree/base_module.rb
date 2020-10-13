module Braintree
  module BaseModule # :nodoc: all
    module Methods
      def return_object_or_raise(object_to_return)
        result = yield
        if result.success?
          result.send object_to_return
        else
          raise ValidationsFailed.new(result)
        end
      end

      def copy_instance_variables_from_object(object)
        object.instance_variables.each do |ivar|
          instance_variable_set ivar, object.instance_variable_get(ivar)
        end
      end

      def set_instance_variables_from_hash(hash)
        hash.each do |key, value|
          if key == :global_id
            instance_variable_set "@graphql_id", value
          end

          instance_variable_set "@#{key}", value
        end
      end

      def singleton_class
        class << self; self; end
      end
    end

    def self.included(klass)
      klass.extend Methods
    end
    include Methods
  end
end
