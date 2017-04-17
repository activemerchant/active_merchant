#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Basic
      module Payment
        module Response
          module Mapper
            class PaymentRefundResponseMapper < ResponseMapper

              def map_response(response, jsonResult)
                super
                response.payment_id = jsonResult['paymentId'] unless jsonResult['paymentId'].nil?
                response.payment_transaction_id = jsonResult['paymentTransactionId'] unless jsonResult['paymentTransactionId'].nil?
                response.price = jsonResult['price'] unless jsonResult['price'].nil?
              end

            end
          end
        end
      end
    end
  end
end
