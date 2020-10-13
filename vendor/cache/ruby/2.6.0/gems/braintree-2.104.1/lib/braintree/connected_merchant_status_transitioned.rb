module Braintree
  class ConnectedMerchantStatusTransitioned
    include BaseModule

    attr_reader :merchant_public_id
    attr_reader :oauth_application_client_id
    attr_reader :status

    alias_method :merchant_id, :merchant_public_id

    def initialize(attributes)
      set_instance_variables_from_hash(attributes)
    end

    class << self
      protected :new
      def _new(*args) # :nodoc:
        self.new *args
      end
    end
  end
end
