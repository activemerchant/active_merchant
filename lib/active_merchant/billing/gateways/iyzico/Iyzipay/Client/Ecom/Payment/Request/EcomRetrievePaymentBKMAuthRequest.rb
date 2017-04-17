module Iyzipay
  module Client
    module Ecom
      module Payment
        module Request
          class EcomRetrievePaymentBKMAuthRequest < Iyzipay::Client::Request
            attr_accessor :token

            def get_json_object
              JsonBuilder.from_json_object(super).
                  add('token', @token).
                  get_object
            end

            def to_PKI_request_string
              PKIRequestStringBuilder.new.append_super(super).
                  append(:token, @token).
                  get_request_string
            end
          end
        end
      end
    end
  end
end