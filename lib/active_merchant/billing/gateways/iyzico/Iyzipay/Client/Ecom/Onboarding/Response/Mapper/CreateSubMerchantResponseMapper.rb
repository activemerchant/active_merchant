#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Ecom
      module Onboarding
        module Response
          module Mapper

            class CreateSubMerchantResponseMapper < ResponseMapper

              def map_response(response, jsonResult)
                super
                response.sub_merchant_key = jsonResult['subMerchantKey'] unless jsonResult['subMerchantKey'].nil?
              end

            end
          end
        end
      end
    end
  end
end
