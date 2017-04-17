#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Basic
      module Payment
        module Response
          module Mapper
            class PaymentPostAuthResponseMapper < ResponseMapper

              def map_response(response, jsonResult)
                super
                response.payment_id = jsonResult['paymentId'] unless jsonResult['paymentId'].nil?
                response.price = jsonResult['price'] unless jsonResult['price'].nil?
              end

            end
          end
        end
      end
    end
  end
end
