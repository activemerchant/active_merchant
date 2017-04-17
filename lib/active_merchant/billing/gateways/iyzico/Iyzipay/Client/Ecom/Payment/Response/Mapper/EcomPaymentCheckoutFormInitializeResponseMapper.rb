#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Ecom
      module Payment
        module Response
          module Mapper
            class EcomPaymentCheckoutFormInitializeResponseMapper < ResponseMapper
              def map_response(response, json_result)
                super
                response.token = json_result['token'] unless json_result['token'].nil?
                response.callback_url = json_result['callback_url'] unless json_result['callback_url'].nil?
                response.payment_status = json_result['payment_status'] unless json_result['payment_status'].nil?
              end
            end
          end
        end
      end
    end
  end
end
