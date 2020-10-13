module Braintree
  class PlanGateway # :nodoc:
    def initialize(gateway)
      @gateway = gateway
      @config = gateway.config
      @config.assert_has_access_token_or_keys
    end

    def all
      response = @config.http.get("#{@config.base_merchant_path}/plans")
      attributes_collection = response[:plans] || []
      attributes_collection.map do |attributes|
        Plan._new(@gateway, attributes)
      end
    end
  end
end
