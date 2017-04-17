module Iyzipay
  module Client
    module Ecom
      module Payment
        module Response
          class EcomRetrievePaymentCheckoutFormAuthResponse < EcomPaymentAuthResponse
            attr_accessor :token
            attr_accessor :callback_url
            attr_accessor :payment_status
            def from_json(json_result)
              Mapper::EcomRetrievePaymentBKMAuthResponseMapper.new.map_response(self, json_result)
            end
          end
        end
      end
    end
  end
end