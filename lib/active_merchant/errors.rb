module ActiveMerchant #:nodoc:
  class ActiveMerchantError < StandardError #:nodoc:
  end

  class ConnectionError < ActiveMerchantError # :nodoc:
    attr_reader :triggering_exception

    def initialize(message, triggering_exception)
      super(message)
      @triggering_exception = triggering_exception
    end
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
