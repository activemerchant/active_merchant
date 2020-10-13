module Braintree
  class AuthorizationAdjustment # :nodoc:
    include BaseModule

    attr_reader :amount
    attr_reader :success
    attr_reader :timestamp
    attr_reader :processor_response_code
    attr_reader :processor_response_text
    attr_reader :processor_response_type

    class << self
      protected :new
      def _new(*args) # :nodoc:
        self.new *args
      end
    end

    def initialize(attributes) # :nodoc:
      set_instance_variables_from_hash(attributes)
    end
  end
end
