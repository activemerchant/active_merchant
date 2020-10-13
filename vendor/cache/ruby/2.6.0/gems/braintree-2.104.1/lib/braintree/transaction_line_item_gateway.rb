module Braintree
  class TransactionLineItemGateway # :nodoc:
    def initialize(gateway)
      @gateway = gateway
      @config = gateway.config
      @config.assert_has_access_token_or_keys
    end

    def find_all(transaction_id)
      raise ArgumentError, "transaction_id cannot be blank" if transaction_id.nil? || transaction_id.strip.to_s == ""
      response = @config.http.get("#{@config.base_merchant_path}/transactions/#{transaction_id}/line_items")
      response[:line_items].map do |line_item_params|
        TransactionLineItem._new(@gateway, line_item_params)
      end
    rescue NotFoundError
      raise NotFoundError, "transaction with id #{transaction_id.inspect} not found"
    end
  end
end
