#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Ecom
      module Onboarding
        module Response
          class CreateSubMerchantResponse < Iyzipay::Client::Response
            attr_accessor :sub_merchant_key

            def from_json(json_result)
              Mapper::CreateSubMerchantResponseMapper.new.map_response(self, json_result)
            end
          end
        end
      end
    end
  end
end
