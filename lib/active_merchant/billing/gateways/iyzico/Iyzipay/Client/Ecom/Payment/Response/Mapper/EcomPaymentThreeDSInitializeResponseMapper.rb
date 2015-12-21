#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Ecom
      module Payment
        module Response
          module Mapper
            class EcomPaymentThreeDSInitializeResponseMapper < Iyzipay::Client::ResponseMapper
              def map_response(response, jsonResult)
                super
                response.payout_completed_transactions = jsonResult['threeDSHtmlContent'] unless jsonResult['threeDSHtmlContent'].nil?
              end
            end
          end
        end
      end
    end
  end
end
