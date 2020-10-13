module Braintree
  class CreditCardVerificationGateway
    def initialize(gateway)
      @gateway = gateway
      @config = gateway.config
      @config.assert_has_access_token_or_keys
    end

    def find(id)
      raise ArgumentError if id.nil? || id.to_s.strip == ""
      response = @config.http.get("#{@config.base_merchant_path}/verifications/#{id}")
      CreditCardVerification._new(response[:verification])
    rescue NotFoundError
      raise NotFoundError, "verification with id #{id.inspect} not found"
    end

    def search(&block)
      search = CreditCardVerificationSearch.new
      block.call(search) if block

      response = @config.http.post("#{@config.base_merchant_path}/verifications/advanced_search_ids", {:search => search.to_hash})
      ResourceCollection.new(response) { |ids| _fetch_verifications(search, ids) }
    end

    def create(params)
      response = @config.http.post("#{@config.base_merchant_path}/verifications", :verification => params)
      _handle_verification_create_response(response)
    end

    def _handle_verification_create_response(response)
      if response[:verification]
        SuccessfulResult.new(:verification => CreditCardVerification._new(response[:verification]))
      elsif response[:api_error_response]
        ErrorResult.new(@gateway, response[:api_error_response])
      else
        raise UnexpectedError, "expected :verification or :api_error_response"
      end
    end

    def _fetch_verifications(search, ids)
      search.ids.in ids
      response = @config.http.post("#{@config.base_merchant_path}/verifications/advanced_search", {:search => search.to_hash})
      attributes = response[:credit_card_verifications]
      Util.extract_attribute_as_array(attributes, :verification).map { |attrs| CreditCardVerification._new(attrs) }
    end

    def self._create_signature
      [
         {:options => [:amount, :merchant_account_id, :account_type]},
         {:credit_card => [
           :cardholder_name, :cvv, :expiration_date, :expiration_month, :expiration_year,
           :number, {:billing_address => AddressGateway._shared_signature}
         ]}
      ]
    end
  end
end
