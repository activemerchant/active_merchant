#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Ecom
      module Payment
        module Response
          module Mapper
            class EcomRetrievePaymentBKMAuthResponseMapper < EcomPaymentResponseMapper
              def map_response(response, jsonResult)
                super
                response.payout_completed_transactions = jsonResult['htmlContent'] unless jsonResult['htmlContent'].nil?
              end
            end
          end
        end
      end
    end
  end
end
