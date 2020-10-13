module Braintree
  class AddOnGateway # :nodoc
    def initialize(gateway)
      @gateway = gateway
      @config = gateway.config
      @config.assert_has_access_token_or_keys
    end

    def all
      response = @config.http.get("#{@config.base_merchant_path}/add_ons")
      attributes_collection = response[:add_ons]
      attributes_collection.map do |attributes|
        AddOn._new(attributes)
      end
    end
  end
end
