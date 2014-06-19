module ActiveMerchant #:nodoc:
  class ActiveMerchantError < StandardError #:nodoc:
  end

  class ConnectionError < ActiveMerchantError # :nodoc:
  end

  class RetriableConnectionError < ConnectionError # :nodoc:
  end

  class ResponseError < ActiveMerchantError # :nodoc:
    attr_reader :response

    def initialize(response, message = nil)
      @response = response
      @message  = message
    end

    def to_s
      "Failed with #{response.code} #{response.message if response.respond_to?(:message)}"
    end
  end

  class ClientCertificateError < ActiveMerchantError # :nodoc
  end

  class InvalidResponseError < ActiveMerchantError # :nodoc
  end
end
