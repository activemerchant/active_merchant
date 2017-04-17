module Iyzipay
  module Client
    module Service
      class EcomCheckoutFormServiceClient < BaseServiceClient
        def self.from_configuration(configuration)
          self.new(configuration)
        end

        def initializeCheckoutForm(request)
          raw_result = HttpClientTemplate.post("#{@configuration.base_url}/payment/iyzipos/checkoutform/initialize/ecom", get_http_header(request), request.to_json_string)
          response = Ecom::Payment::Response::EcomPaymentCheckoutFormInitializeResponse.new
          json_decode_and_prepare_response(response, raw_result)
          response
        end

        def getAuthResponse(request)
          raw_result = HttpClientTemplate.post("#{@configuration.base_url}/payment/iyzipos/checkoutform/auth/ecom/detail", get_http_header(request), request.to_json_string)
          response = Ecom::Payment::Response::EcomRetrievePaymentCheckoutFormAuthResponse.new
          json_decode_and_prepare_response(response, raw_result)
          response
        end

      end
    end
  end
end
