module Braintree
  class ClientTokenGateway
    include BaseModule

    def initialize(gateway)
      @gateway = gateway
      @config = gateway.config
      @config.assert_has_access_token_or_keys
    end

    def generate(options={})
      _validate_options(options)

      options[:version] ||= ClientToken::DEFAULT_VERSION

      Util.verify_keys(ClientTokenGateway._generate_signature, options)

      params = {:client_token => options}
      result = @config.http.post("#{@config.base_merchant_path}/client_token", params)

      if result[:client_token]
        result[:client_token][:value]
      else
        raise ArgumentError, result[:api_error_response][:message]
      end
    end

    def self._generate_signature # :nodoc:
      [
        :address_id, :customer_id, :proxy_merchant_id, :merchant_account_id,
        :version,
        {:options => [:make_default, :verify_card, :fail_on_duplicate_payment_method]}
      ]
    end

    def _validate_options(options)
      [:make_default, :fail_on_duplicate_payment_method, :verify_card].each do |credit_card_option|
        if options[credit_card_option]
          raise ArgumentError.new("cannot specify #{credit_card_option} without a customer_id") unless options[:customer_id]
        end
      end
    end
  end
end
