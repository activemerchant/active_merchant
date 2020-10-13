module Braintree
  class ApplePayGateway
    def initialize(gateway)
      @gateway = gateway
      @config = gateway.config
    end

    def register_domain(domain)
      response = @config.http.post("#{@config.base_merchant_path}/processing/apple_pay/validate_domains", :url => domain)

      if response.has_key?(:response) && response[:response][:success]
        Braintree::SuccessfulResult.new
      elsif response[:api_error_response]
        ErrorResult.new(@gateway, response[:api_error_response])
      else
        raise "expected :response or :api_error_response"
      end
    end

    def unregister_domain(domain)
      @config.http.delete("#{@config.base_merchant_path}/processing/apple_pay/unregister_domain", :url => CGI.escape(domain))
      SuccessfulResult.new
    end

    def registered_domains
      response = @config.http.get("#{@config.base_merchant_path}/processing/apple_pay/registered_domains")

      if response.has_key?(:response)
        Braintree::SuccessfulResult.new(:apple_pay_options => ApplePayOptions._new(response[:response]))
      elsif response[:api_error_response]
        ErrorResult.new(@gateway, response[:api_error_response])
      else
        raise "expected :response or :api_error_response"
      end
    end
  end
end
