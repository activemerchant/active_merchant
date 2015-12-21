#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Ecom
      module Onboarding
        module Response
          class UpdateSubMerchantResponse < Iyzipay::Client::Response

            def from_json(json_result)
              Mapper::UpdateSubMerchantResponseMapper.new.map_response(self, json_result)
            end

          end
        end
      end
    end
  end
end
