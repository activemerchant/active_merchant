#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Ecom
      module Approval
        module Response
          module Mapper
            class ApprovalResponseMapper < ResponseMapper

              def map_response(response, jsonResult)
                super
                response.payment_transaction_id = jsonResult['paymentTransactionId'] unless jsonResult['paymentTransactionId'].nil?
              end

            end
          end
        end
      end
    end
  end
end
